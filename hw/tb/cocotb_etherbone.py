#
# Cocotb testbench with virtual Wishbone bus over Etherbone and virtual display.
#

import numpy
import os
from itertools import repeat
from queue import Queue, Empty as queue_empty
import logging

import cocotb
from cocotb.triggers import Timer, Edge
from cocotb.clock import Clock
from cocotbext.wishbone.driver import WishboneMaster
from cocotbext.wishbone.monitor import WishboneSlave
from cocotbext.wishbone.driver import WBOp
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame

from etherbone import RemoteServer

from gpu_display import GpuDisplay


# Defines
GPU_REG_OFFSET  = 0x90000000
MEM_OFFSET      = 0x40000000
FB_OFF_REG_ADDR = 0x3800
MEMORY_SIZE     = 64*1024*1024

CLK_PERIOD      = 10
WB_ACK_DELAY    = 1

DISPLAY_SIZE_X  = 640
DISPLAY_SIZE_Y  = 480
DISPLAY_BPP     = 4
FB_SIZE         = DISPLAY_SIZE_X*DISPLAY_SIZE_Y*DISPLAY_BPP

WBM_SIGNALS_DICT ={"cyc":  "cyc_i",
                  "stb":  "stb_i",
                  "we":   "we_i",
                  "adr":  "adr_i",
                  "datwr":"dat_i",
                  "datrd":"dat_o",
                  "ack":  "ack_o" }

WBS_SIGNALS_DICT ={"cyc":  "cyc_o",
                  "stb":  "stb_o",
                  "we":   "we_o",
                  "adr":  "adr_o",
                  "datwr":"dat_o",
                  "datrd":"dat_i",
                  "ack":  "ack_i" }
                  
                  
# Helpers
def wba2addr(wb_addr):
    # convert wishbone address to convinient form
    return wb_addr*4
    
def addr2wba(addr):
    # convert address to wishbone
    return addr//4

def wba2off(wb_addr):
    # convert wishbone memory address to array offset
    return wb_addr - MEM_OFFSET//4
    
def addr2off(addr):
    # convert memory address to array offset
    return (addr - MEM_OFFSET) // 4


# Main class
class GpuPipeWishboneWrapper:
    
    def __init__(self, dut, base_addr):
        self.dut = dut
        self.reg_base = base_addr[0]
        self.mem_base = base_addr[1]
        self.zb_base = base_addr[2]
        self.fb_base = base_addr[3]
        self.back_fb_base = base_addr[4]
        
        # connect clocks and other signals
        cocotb.start_soon(self.short(dut.cache_inv_o, dut.cache_inv_i))
        clk = dut.clk
        
        if "NO_VERILOG_CLK_GEN" in os.environ:
            # ugly hack for Verilator
            # generate clocks in cocotb as clocks from Verilog break Verilator sim with --timing for some reason
            cocotb.start_soon(Clock(clk, 8, units = "ns").start())
            cocotb.start_soon(Clock(dut.gpu_clk, 10, units = "ns").start())
            
        
        # create memory
        self.memory = numpy.zeros(MEMORY_SIZE, dtype='uint32')
        
        # create testbench-master -> GPU-slave wishbone interface to GPU regs
        self.reg_wbs = WishboneMaster(self.dut, "wbs", clk, width = 32, timeout = 1000, signals_dict = WBM_SIGNALS_DICT)
        
        # create GPU-master -> testbench-slave wishbone interfaces to memory
        self.cmd_wbm = WishboneSlave(self.dut, "cmd_wb", clk, width = 32, signals_dict = WBS_SIGNALS_DICT, waitreplygen=repeat(WB_ACK_DELAY), datgen=self.wb_mem_read("cmd"))
        self.cmd_wbm.add_callback(self.cmd_wb_callback)
        
        self.tex_wbm = WishboneSlave(self.dut, "tex_wb", clk, width = 32, signals_dict = WBS_SIGNALS_DICT, waitreplygen=repeat(WB_ACK_DELAY), datgen=self.wb_mem_read("tex"))
        self.tex_wbm.add_callback(self.wb_mem_write)    # no writes from here actually
        
        self.frag_wbm = WishboneSlave(self.dut, "frag_wb", clk, width = 32, signals_dict = WBS_SIGNALS_DICT, waitreplygen=repeat(WB_ACK_DELAY), datgen=self.wb_mem_read("frag"))
        self.frag_wbm.add_callback(self.frag_wb_callback)
        
        self.fb_wbm = WishboneSlave(self.dut, "fb_wb", clk, width = 32, signals_dict = WBS_SIGNALS_DICT, waitreplygen=repeat(WB_ACK_DELAY), datgen=self.wb_mem_read("fb"))
        self.fb_wbm.add_callback(self.fb_wb_callback)
        
        # create crossclock stream FIFOs emulation
        self.axis_wb_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "axis_wb"), dut.clk, dut.rst_i)
        self.axis_wb_sink.log.setLevel(logging.WARNING)
        self.axis_cmd_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "axis_cmd"), dut.gpu_clk, dut.gpu_rst_i)
        self.axis_cmd_source.log.setLevel(logging.WARNING)
        cocotb.start_soon(self.stream_fifo(self.axis_wb_sink, self.axis_cmd_source))
        self.axis_rast_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "axis_rast"), dut.gpu_clk, dut.rst_i)
        self.axis_rast_sink.log.setLevel(logging.WARNING)
        self.axis_tex_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "axis_tex"), dut.clk, dut.gpu_rst_i)
        self.axis_tex_source.log.setLevel(logging.WARNING)
        cocotb.start_soon(self.stream_fifo(self.axis_rast_sink, self.axis_tex_source))
        
        # connect stream signals without FIFOs
        # cocotb.start_soon(self.short(self.dut.axis_wb_tvalid, self.dut.axis_cmd_tvalid))
        # cocotb.start_soon(self.short(self.dut.axis_cmd_tready, self.dut.axis_wb_tready))
        # cocotb.start_soon(self.short(self.dut.axis_wb_tdata, self.dut.axis_cmd_tdata))
        # cocotb.start_soon(self.short(self.dut.axis_rast_tvalid, self.dut.axis_tex_tvalid))
        # cocotb.start_soon(self.short(self.dut.axis_tex_tready, self.dut.axis_rast_tready))
        # cocotb.start_soon(self.short(self.dut.axis_rast_tdata, self.dut.axis_tex_tdata))
        
        
        
        # prepare to serve etherbone requests
        self.request_queue = Queue()
        self.reads_queue = Queue()
        cocotb.start_soon(self.etherbone_monitor())
        
        # create display
        self.display = GpuDisplay(DISPLAY_SIZE_X, DISPLAY_SIZE_Y, 32)
        self.frame_cnt = 0
        
        # reset GPU
        cocotb.start_soon(self.reset())
        
    # Helper shorting two signals
    async def short(self, src, dst):
        while True:
            await cocotb.triggers.Edge(src)
            dst.value = src.value
            
    # Reset GPU
    async def reset(self):
        self.dut.rst_i.value = 1
        self.dut.gpu_rst_i.value = 1
        await Timer(1, "us")
        self.dut.rst_i.value = 0
        self.dut.gpu_rst_i.value = 0
        
        while True:
            await cocotb.triggers.Edge(self.dut.resetme_o)
            # connect self reset
            self.dut.rst_i.value = self.dut.gpu_rst_i.value = self.dut.resetme_o.value
        
    # Emulate stream FIFO
    async def stream_fifo(self, src, sink):
        while True:
            frame = (await src.recv())
            await sink.send(frame)
                          
    # Etherbone monitor coroutine    
    async def etherbone_monitor(self):
        # poll request queue from time to time
        idle = False
        display_cnt = 0
        while (True):
            if idle:
                # advance simulation timer when idle
                await Timer(1, "us")
                display_cnt += 5
            try:
                # process etherbone requests from queue
                req = self.request_queue.get_nowait()
                idle = False
                
                addr = req[1]
                if addr < self.reg_base:
                    assert(addr > MEM_OFFSET)
                    off = addr2off(addr)
                    # memory access
                    if req[0]:
                        self.reads_queue.put(self.read_mem(off))
                    else:
                        self.write_mem(off, req[2])
                else:
                    # register bus access
                    wb = self.reg_wbs
                
                    if req[0]:
                        self.reads_queue.put(await self.wb_slv_read(wb, addr))
                    else:
                        await self.wb_slv_write(wb, addr, req[2])
                    
            except queue_empty:
                idle = True
                
            if display_cnt == 20:
                self.display.Tick()
                display_cnt = 0
            else:
                display_cnt += 1
        
    # Read GPU reg bus
    async def wb_slv_read(self, wb, addr):
        wbres = await wb.send_cycle([WBOp(adr=addr2wba(addr))]) 
        return wbres[0].datrd
        
    # Write GPU reg bus
    async def wb_slv_write(self, wb, addr, dat):
        wbres = await wb.send_cycle([WBOp(adr=addr2wba(addr), dat=dat)]) 
    
    # Callback for writes from CMD bus    
    def cmd_wb_callback(self, transaction):
        fb = self.fb_base
        for t in transaction:
            addr = wba2addr(t.adr.integer)
            if (addr == FB_OFF_REG_ADDR):
                # emulate litex framebufer base reg
                # works properly only if backbuffer was cleared before drawing
                self.back_fb_base = fb
                self.fb_base = (fb & 0xF0000000) + t.datwr.integer
                self.display.DrawFramebuffer()
                self.frame_cnt += 1
                print("Frame", self.frame_cnt)
            else:
                assert(addr > MEM_OFFSET)
                self.wb_mem_write([t])
        
    # Callback for writes from FB bus
    def fb_wb_callback(self, transaction):
        fb = self.back_fb_base
        for t in transaction:
            if (t.adr.integer == 0xFFFFFFFF):
                # fast FB clear for simulation
                self.display.ClearFramebuffer()
                self.memory[addr2off(fb):addr2off(fb+FB_SIZE)] = t.datwr.integer
            else:
                addr = wba2addr(t.adr.integer)
                self.wb_mem_write([t])
                assert((addr >= fb) and (addr < fb + FB_SIZE))
                off = (addr - fb) // DISPLAY_BPP
                argb = (t.datwr.integer & 0xFF00FF00) | (t.datwr.integer & 0x00FF0000) >> 16 | (t.datwr.integer & 0x000000FF) << 16 # exchange R & B to be LiteX FB compatible
                self.display.PutFragment((off % DISPLAY_SIZE_X, DISPLAY_SIZE_Y-1 - (off // DISPLAY_SIZE_X), 0, argb))
        
    # Callback for writes from FRAG bus
    def frag_wb_callback(self, transaction):
        for t in transaction:
            if (t.adr.integer == 0xFFFFFFFF):
                # fast ZB clear for simulation
                self.memory[addr2off(self.zb_base):addr2off(self.zb_base+FB_SIZE)] = t.datwr.integer
            else:
                self.wb_mem_write([t])
    
    # Memory read from wishbone handler
    def wb_mem_read(self, bus_name):
        if bus_name == "cmd":
            wb = self.cmd_wbm
        elif bus_name == "tex":
            wb = self.tex_wbm
        elif bus_name == "frag":
            wb = self.frag_wbm
        elif bus_name == "fb":
            wb = self.fb_wbm
        else:
            assert(False)
            
        while True:
            off = wba2off(wb.bus.adr.value.integer)
            yield self.read_mem(off)
            
    # Generic Wishbone memory write
    def wb_mem_write(self, transaction):
        for t in transaction:
            if (t.datwr):
                adr = wba2off(t.adr.integer)
                self.write_mem(adr, t.datwr.integer)
                
    # Read & write to memory helpers
    def read_mem(self, off):
        return self.memory[off].item()
        
    def write_mem(self, off, dat):
        self.memory[off] = numpy.uint32(dat)
        
    # Read from etherbone
    def read(self, addr):
        self.request_queue.put((True, addr))
        return [self.reads_queue.get()]
        
    # Write from etherbone
    def write(self, addr, dat):
        assert(len(dat) == 1)
        self.request_queue.put((False, addr, dat[0]))
    
    # Needed for etherbone    
    def open(self):
        pass
        
    def close(self):
        pass


# Cocotb test
@cocotb.test()
async def testbech(dut):
    # create Wishbone wrapper
    wishbone = GpuPipeWishboneWrapper(dut, (GPU_REG_OFFSET, MEM_OFFSET, 0x40A00000, 0x40D30000, 0x40C00000))
    
    # launch etherbone server
    server = RemoteServer(wishbone, "127.0.0.1", 1234, 32)
    server.open()
    server.start(4)
    
    # simulate one second
    await Timer(1000, "ms")
    
            
