#
# LiteX wrapper for OpenGlory GPU. 
# Contains DRAM connections, reset logic & frequency domain crossing FIFOs.
#
from migen import *
from migen.genlib.cdc import MultiReg

from litex.soc.interconnect import stream
from litescope import LiteScopeAnalyzer

from litex.soc.integration.soc import SoCRegion
from litex.soc.interconnect import wishbone
from litedram.frontend.wishbone import LiteDRAMWishbone2Native
from math import log2, ceil

from wb_cache.wb_cache import FlushableCache

GENERATE_ANALYZER = False

class WBGpu(Module):

    def __init__(self, cd_sys, cd_gpu, rst, wbmasters, wbs, cache_inv_req, cache_inv_active):
    
        self.submodules.cmd_fifo  = cmd_fifo  = ClockDomainsRenamer({"write": "sys", "read": "gpu"})(stream.AsyncFIFO([("data", 32)], 32))
        self.submodules.cc_fifo   = cc_fifo   = ClockDomainsRenamer({"write": "gpu", "read": "sys"})(stream.AsyncFIFO([("data", 32)], 32))
        
        gpu_rst_gpu = Signal(1)
        gpu_rst_sys = Signal(1)
        resetme     = Signal(1)
        self_rst    = Signal(1)
        reset_cnt   = Signal(4)
        
        # Form reset for GPU from PLL and self reset
        self.comb += [
            gpu_rst_sys.eq(rst | self_rst)
        ]
        
        # GPU self reset counter
        self.sync += [
            If (resetme,
                reset_cnt.eq(0),
                self_rst.eq(1)
            ).Elif(reset_cnt >= 10,
                self_rst.eq(0)
            ).Else(
                reset_cnt.eq(reset_cnt + 1)
            )
        ]
        
        # Pass reset to GPU freq domain
        self.specials += MultiReg(gpu_rst_sys, gpu_rst_gpu, "gpu", reset = 1)
        
        # Instantiate VHDL OpenGlory module
        self.specials += Instance("gpu_pipe_wb",
            i_clk_i        = cd_sys.clk,
            i_gpu_clk_i    = cd_gpu.clk,
            i_gpu_rst_i    = gpu_rst_gpu,
            i_rst_i        = gpu_rst_sys,
            o_resetme_o    = resetme,
            
            i_axis_cmd_valid_i  = cmd_fifo.source.valid,
            i_axis_cmd_data_i   = cmd_fifo.source.data,
            o_axis_cmd_ready_o  = cmd_fifo.source.ready,
            
            o_wb_cmd_valid_o    = cmd_fifo.sink.valid,
            o_wb_cmd_data_o     = cmd_fifo.sink.data,
            i_wb_cmd_ready_i    = cmd_fifo.sink.ready,
            
            i_axis_tex_valid_i  = cc_fifo.source.valid,
            i_axis_tex_data_i   = cc_fifo.source.data,
            o_axis_tex_ready_o  = cc_fifo.source.ready,
            
            o_axis_rast_valid_o = cc_fifo.sink.valid,
            o_axis_rast_data_o  = cc_fifo.sink.data,
            i_axis_rast_ready_i = cc_fifo.sink.ready,
            
            o_cmd_wb_stb_o = wbmasters[0].stb,
            o_cmd_wb_cyc_o = wbmasters[0].cyc,
            o_cmd_wb_adr_o = wbmasters[0].adr,
            o_cmd_wb_we_o  = wbmasters[0].we,
            o_cmd_wb_sel_o = wbmasters[0].sel,
            o_cmd_wb_dat_o = wbmasters[0].dat_w,
            i_cmd_wb_dat_i = wbmasters[0].dat_r,
            i_cmd_wb_ack_i = wbmasters[0].ack,
            
            o_tex_wb_stb_o = wbmasters[1].stb,
            o_tex_wb_cyc_o = wbmasters[1].cyc,
            o_tex_wb_adr_o = wbmasters[1].adr,
            o_tex_wb_we_o  = wbmasters[1].we,
            o_tex_wb_sel_o = wbmasters[1].sel,
            o_tex_wb_dat_o = wbmasters[1].dat_w,
            i_tex_wb_dat_i = wbmasters[1].dat_r,
            i_tex_wb_ack_i = wbmasters[1].ack,
            
            o_frag_wb_stb_o = wbmasters[2].stb,
            o_frag_wb_cyc_o = wbmasters[2].cyc,
            o_frag_wb_adr_o = wbmasters[2].adr,
            o_frag_wb_we_o  = wbmasters[2].we,
            o_frag_wb_sel_o = wbmasters[2].sel,
            o_frag_wb_dat_o = wbmasters[2].dat_w,
            i_frag_wb_dat_i = wbmasters[2].dat_r,
            i_frag_wb_ack_i = wbmasters[2].ack,
            
            o_fb_wb_stb_o = wbmasters[3].stb,
            o_fb_wb_cyc_o = wbmasters[3].cyc,
            o_fb_wb_adr_o = wbmasters[3].adr,
            o_fb_wb_we_o  = wbmasters[3].we,
            o_fb_wb_sel_o = wbmasters[3].sel,
            o_fb_wb_dat_o = wbmasters[3].dat_w,
            i_fb_wb_dat_i = wbmasters[3].dat_r,
            i_fb_wb_ack_i = wbmasters[3].ack,
            
            i_wbs_stb_i = wbs.stb,
            i_wbs_cyc_i = wbs.cyc,
            i_wbs_adr_i = wbs.adr,
            i_wbs_we_i  = wbs.we,
            o_wbs_sel_i = wbs.sel,
            i_wbs_dat_i = wbs.dat_w,
            o_wbs_dat_o = wbs.dat_r,
            o_wbs_ack_o = wbs.ack,
            
            o_cache_inv_o = cache_inv_req,
            i_cache_inv_i = cache_inv_active,
        )
         
        if GENERATE_ANALYZER:
            analyzer_signals = [ wbmasters[0], wbmasters[2], wbmasters[3] ]
            self.analyzer = LiteScopeAnalyzer(analyzer_signals,
                depth        = 128,
                clock_domain = "sys",
                samplerate   = 100000000,
                csr_csv      = "analyzer.csv"
            )
    
def add_openglory_gpu(soc, sdram, reg_addr, gpu_file_list, gpu_cache_sizes_kb = [16, 16, 16]):
    GPU_WB_MST_CNT = 4
    cache_inv_req = Signal(3)
    cache_inv_active = Signal(3)
    cache_min_data_width = 128
    cache_full_memory_we = True
    wbm_gpu_buses = []
    dma_bus = getattr(soc, "dma_bus", soc.bus)
    
    # Connect OpenGlory WB buses 
    for i in range(GPU_WB_MST_CNT):
        wbm_gpu_buses.append(wishbone.Interface())
        
        if i > 0:
        # if (i == 1) or (i == 3):
            # Dedicated dram port
            port = sdram.crossbar.get_port()
            port.data_width = 2**int(log2(port.data_width)) # Round to nearest power of 2.
            cache_size = gpu_cache_sizes_kb[i-1] * 1024
            
            # Add cache
            if cache_size != 0:
                # Insert cache inbetween Wishbone bus and LiteDRAM
                cache_data_width = max(port.data_width, cache_min_data_width)
                cache = FlushableCache(
                    cachesize = cache_size//4,
                    master    = wbm_gpu_buses[i],
                    slave     = wishbone.Interface(data_width=cache_data_width, address_width=32, addressing="word"),
                    invalidate_i = cache_inv_req[i-1],
                    invalidate_o = cache_inv_active[i-1],
                    reverse   = False)
                if cache_full_memory_we:
                    cache = FullMemoryWE()(cache)
                soc.submodules += cache
                litedram_wb = cache.slave
            else:
                soc.comb += [cache_inv_active.eq(cache_inv_req)]    # shortcut invalidate if no cache
                litedram_wb = wishbone.Interface(data_width=port.data_width, address_width=32, addressing="word")
                soc.submodules += wishbone.Converter(wbm_gpu_buses[i], litedram_wb)
            
            soc.wishbone_bridge = LiteDRAMWishbone2Native(
                wishbone     = litedram_wb,
                port         = port,
                base_address = soc.bus.regions["main_ram"].origin
            )
        else:
            dma_bus.add_master("openglory_wb_"+str(i), wbm_gpu_buses[i])
            
    wbs_gpu_bus = wishbone.Interface()
    wbgpu = WBGpu(soc.crg.cd_sys, soc.crg.cd_gpu, soc.crg.rst, wbm_gpu_buses, wbs_gpu_bus, cache_inv_req, cache_inv_active)
    soc.submodules.wbgpu = wbgpu
    soc.bus.add_slave(name="openglory_wb_regs", slave=wbs_gpu_bus, region=SoCRegion(size=0x1000, origin=reg_addr, cached=False))
    for f in gpu_file_list:
        soc.platform.add_source(f)
        
    if GENERATE_ANALYZER:
        soc.submodules.analyzer = wbgpu.analyzer


