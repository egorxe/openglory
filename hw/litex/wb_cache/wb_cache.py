from migen import *
from litex.gen import *
from litex.gen.genlib.misc import split, displacer, chooser
from litex.soc.interconnect import wishbone

class FlushableCache(LiteXModule):
    """FlushableCache

    This module is a write-back wishbone cache that can be used as a L2 cache with full cache invalidate ability.
    Cachesize (in 32-bit words) is the size of the data store and must be a power of 2
    """
    def __init__(self, cachesize, master, slave, invalidate_i, invalidate_o, reverse=True):
        self.master = master
        self.slave  = slave

        # # #

        dw_from = len(master.dat_r)
        dw_to = len(slave.dat_r)
        if dw_to > dw_from and (dw_to % dw_from) != 0:
            raise ValueError("Slave data width must be a multiple of {dw}".format(dw=dw_from))
        if dw_to < dw_from and (dw_from % dw_to) != 0:
            raise ValueError("Master data width must be a multiple of {dw}".format(dw=dw_to))
            
        invalidate_active = Signal(1, reset=1)
        invalidate_adr = Signal(len(master.adr))
        mux_adr = Signal(len(master.adr))
        self.comb += [
            mux_adr.eq(Mux(invalidate_active, invalidate_adr, master.adr)),
            invalidate_o.eq(invalidate_active)
        ]

        # Split address:
        # TAG | LINE NUMBER | LINE OFFSET
        offsetbits = log2_int(max(dw_to//dw_from, 1))
        addressbits = len(slave.adr) + offsetbits
        linebits = log2_int(cachesize) - offsetbits
        tagbits = addressbits - linebits
        wordbits = log2_int(max(dw_from//dw_to, 1))
        adr_offset, adr_line, adr_tag = split(mux_adr, offsetbits, linebits, tagbits)
        word = Signal(wordbits) if wordbits else None

        # Data memory
        data_mem = Memory(dw_to*2**wordbits, 2**linebits)
        data_port = data_mem.get_port(write_capable=True, we_granularity=8)
        self.specials += data_mem, data_port

        write_from_slave = Signal()
        if adr_offset is None:
            adr_offset_r = None
        else:
            adr_offset_r = Signal(offsetbits, reset_less=True)
            self.sync += adr_offset_r.eq(adr_offset)

        self.comb += [
            data_port.adr.eq(adr_line),
            If(write_from_slave,
                displacer(slave.dat_r, word, data_port.dat_w),
                displacer(Replicate(1, dw_to//8), word, data_port.we)
            ).Else(
                data_port.dat_w.eq(Replicate(master.dat_w, max(dw_to//dw_from, 1))),
                If(master.cyc & master.stb & master.we & master.ack,
                    displacer(master.sel, adr_offset, data_port.we, 2**offsetbits, reverse=reverse)
                )
            ),
            chooser(data_port.dat_r, word, slave.dat_w),
            slave.sel.eq(2**(dw_to//8)-1),
            chooser(data_port.dat_r, adr_offset_r, master.dat_r, reverse=reverse)
        ]


        # Tag memory
        tag_layout = [("tag", tagbits), ("dirty", 1), ("valid", 1)]
        tag_mem = Memory(layout_len(tag_layout), 2**linebits)
        tag_port = tag_mem.get_port(write_capable=True)
        self.specials += tag_mem, tag_port
        tag_do = Record(tag_layout)
        tag_di = Record(tag_layout)
        self.comb += [
            tag_do.raw_bits().eq(tag_port.dat_r),
            tag_port.dat_w.eq(tag_di.raw_bits())
        ]

        self.comb += [
            tag_port.adr.eq(adr_line),
            tag_di.tag.eq(adr_tag)
        ]
        if word is not None:
            self.comb += slave.adr.eq(Cat(word, adr_line, tag_do.tag))
        else:
            self.comb += slave.adr.eq(Cat(adr_line, tag_do.tag))

        # slave word computation, word_clr and word_inc will be simplified
        # at synthesis when wordbits=0
        word_clr = Signal()
        word_inc = Signal()
        if word is not None:
            self.sync += \
                If(word_clr,
                    word.eq(0),
                ).Elif(word_inc,
                    word.eq(word+1)
                )

        def word_is_last(word):
            if word is not None:
                return word == 2**wordbits-1
            else:
                return 1

        # Control FSM
        self.fsm = fsm = FSM(reset_state="INVALIDATE_CHECK")
        fsm.act("IDLE",
            If(invalidate_i,
                NextValue(invalidate_active, 1),
                NextState("INVALIDATE_CHECK")
            ).Elif(master.cyc & master.stb,
                NextState("TEST_HIT")
            )
        )
        fsm.act("TEST_HIT",
            word_clr.eq(1),
            If((tag_do.tag == adr_tag) & (tag_do.valid == 1),
                master.ack.eq(1),
                If(master.we,
                    tag_di.dirty.eq(1),
                    tag_di.valid.eq(1),
                    tag_port.we.eq(1)
                ),
                NextState("IDLE")
            ).Else(
                If(tag_do.dirty & tag_do.valid,
                    NextState("EVICT")
                ).Else(
                    # Write the tag first to set the slave address
                    tag_port.we.eq(1),
                    word_clr.eq(1),
                    NextState("REFILL")
                )
            )
        )

        fsm.act("EVICT",
            slave.stb.eq(1),
            slave.cyc.eq(1),
            slave.we.eq(1),
            If(slave.ack,
                word_inc.eq(1),
                 If(word_is_last(word),
                    # Write the tag first to set the slave address
                    tag_port.we.eq(1),
                    word_clr.eq(1),
                    If(invalidate_active,
                        NextState("INVALIDATE"),
                    ).Else(
                        NextState("REFILL")
                    )
                )
            )
        )
        fsm.act("REFILL",
            slave.stb.eq(1),
            slave.cyc.eq(1),
            slave.we.eq(0),
            If(slave.ack,
                write_from_slave.eq(1),
                word_inc.eq(1),
                If(word_is_last(word),
                    tag_di.valid.eq(1),
                    tag_port.we.eq(1),
                    NextState("TEST_HIT"),
                ).Else(
                    NextState("REFILL")
                )
            )
        )
        
        # Read tag during invalidation
        fsm.act("INVALIDATE_CHECK",
            tag_port.we.eq(0),
            NextState("INVALIDATE"),
        )
        
        # Set all valid bits to zero
        fsm.act("INVALIDATE",
            If(tag_do.dirty & tag_do.valid,
                # flush data
                NextState("EVICT")  
            ).Else(
                tag_port.we.eq(1),
                tag_di.valid.eq(0),
                If(invalidate_adr == 2**(linebits+offsetbits)-2**offsetbits,
                    # invalidation done
                    NextValue(invalidate_adr, 0),
                    NextValue(invalidate_active, 0),
                    NextState("IDLE")
                ).Else(
                    # invalidate next cache line
                    NextValue(invalidate_adr, invalidate_adr+2**offsetbits),
                    NextState("INVALIDATE_CHECK") 
                )
            )
        )

class CacheTest(Module):
    def __init__(self, wb_mst_cyc, wb_mst_stb, wb_mst_we, wb_mst_adr, wb_mst_di, wb_mst_do, wb_mst_ack, 
                    wb_slv_cyc, wb_slv_stb, wb_slv_we, wb_slv_adr, wb_slv_di, wb_slv_do, wb_slv_ack, inv):
        mst = wishbone.Interface(data_width=32, address_width=32, addressing="word")
        slv = wishbone.Interface(data_width=128, address_width=32, addressing="word")
        
        inv_active = Signal(1)
        
        self.comb += [
            wb_slv_cyc.eq(slv.cyc),
            wb_slv_stb.eq(slv.stb),
            wb_slv_we.eq(slv.we),
            wb_slv_adr.eq(slv.adr),
            wb_slv_do.eq(slv.dat_w),
            slv.dat_r.eq(wb_slv_di),
            slv.ack.eq(wb_slv_ack),
            
            mst.cyc.eq(wb_mst_cyc),
            mst.stb.eq(wb_mst_stb),
            mst.we.eq(wb_mst_we),
            mst.adr.eq(wb_mst_adr),
            mst.dat_w.eq(wb_mst_do),
            wb_mst_di.eq(mst.dat_r),
            wb_mst_ack.eq(mst.ack),
            mst.sel.eq(0xFFFF)
        ]
        self.submodules.cache = FlushableCache(1024, mst, slv, inv, inv_active)

if __name__ == "__main__":
    # generate Verilog if called directly (for testing)
    from migen.fhdl import verilog
    
    wb_slv_cyc = Signal(1)
    wb_slv_stb = Signal(1)
    wb_slv_we  = Signal(1)
    wb_slv_adr = Signal(32)
    wb_slv_di  = Signal(128)
    wb_slv_do  = Signal(128)
    wb_slv_ack = Signal(1)
    wb_mst_cyc = Signal(1)
    wb_mst_stb = Signal(1)
    wb_mst_we  = Signal(1)
    wb_mst_adr = Signal(32)
    wb_mst_di  = Signal(32)
    wb_mst_do  = Signal(32)
    wb_mst_ack = Signal(1)
    inv = Signal(1)
    
    my_cache = CacheTest(wb_mst_cyc, wb_mst_stb, wb_mst_we, wb_mst_adr, wb_mst_di, wb_mst_do, wb_mst_ack, 
                        wb_slv_cyc, wb_slv_stb, wb_slv_we, wb_slv_adr, wb_slv_di, wb_slv_do, wb_slv_ack, inv)
    cache_verilog = verilog.convert(my_cache, ios={wb_mst_cyc, wb_mst_stb, wb_mst_we, wb_mst_adr, wb_mst_di, wb_mst_do, wb_mst_ack, 
                        wb_slv_cyc, wb_slv_stb, wb_slv_we, wb_slv_adr, wb_slv_di, wb_slv_do, wb_slv_ack, inv})
    print(str(cache_verilog)[:-11] + "initial begin $dumpfile(\"test.vcd\"); $dumpvars(0); end\nendmodule")
    
