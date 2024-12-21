# Cocotb testbench with virtual Wishbone bus over Etherbone and virtual display.
#

import cocotb
from cocotb.triggers import Timer
from cocotbext.wishbone.driver import WishboneMaster
from cocotbext.wishbone.monitor import WishboneSlave
from cocotbext.wishbone.driver import WBOp

from etherbone import RemoteServer
from queue import Queue, Empty as queue_empty

from gpu_display import GpuDisplay

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

class WishboneDriver:
    def __init__(self, dut, reg_base, fb_base):
        self.dut = dut
        self.reg_base = reg_base
        self.fb_base = fb_base[0]
        self.back_fb_base = fb_base[1]
        self.clk = self.dut.clk
        self.ext_wbs = WishboneMaster(self.dut, "ext_wbs", self.clk, width = 32, timeout = 1000, signals_dict = WBM_SIGNALS_DICT)
        self.mem_wbs = WishboneMaster(self.dut, "mem_wbs", self.clk, width = 32, timeout = 1000, signals_dict = WBM_SIGNALS_DICT)
        
        self.fb_wbm = WishboneSlave(self.dut, "fb_wbm", self.clk, width = 32, signals_dict = WBS_SIGNALS_DICT)
        self.fb_wbm.add_callback(self.fb_wb_callback)
        
        self.cmd_wbm = WishboneSlave(self.dut, "cmd_wbm", self.clk, width = 32, signals_dict = WBS_SIGNALS_DICT)
        self.cmd_wbm.add_callback(self.cmd_wb_callback)
        
        self.request_queue = Queue()
        self.reads_queue = Queue()
                          
        cocotb.start_soon(self.etherbone_monitor())
        
        self.display = GpuDisplay(DISPLAY_SIZE_X, DISPLAY_SIZE_Y, 32)
        self.frame_cnt = 0
                          
    def open(self):
        pass
        
    def close(self):
        pass
        
    async def etherbone_monitor(self):
        # poll request queue from time to time
        idle = False
        display_cnt = 0
        while (True):
            if idle:
                await Timer(1, "us")
                display_cnt += 5
            try:
                req = self.request_queue.get_nowait()
                idle = False
                
                addr = req[1]
                if addr < self.reg_base:
                    wb = self.mem_wbs
                else:
                    wb = self.ext_wbs
                
                if req[0]:
                    self.reads_queue.put(await self.wb_read(wb, addr))
                else:
                    await self.wb_write(wb, addr, req[2])
                    
            except queue_empty:
                idle = True
                
            if display_cnt == 20:
                self.display.Tick()
                display_cnt = 0
            else:
                display_cnt += 1
        
    async def wb_read(self, wb, addr):
        wbres = await wb.send_cycle([WBOp(adr=addr)]) 
        return wbres[0].datrd
        
    async def wb_write(self, wb, addr, dat):
        wbres = await wb.send_cycle([WBOp(adr=addr, dat=dat)]) 
        
    def cmd_wb_callback(self, transaction):
        fb = self.fb_base
        for t in transaction:
            if (t.adr.integer == 0x3800):
                self.back_fb_base = fb
                self.fb_base = (fb & 0xF0000000) + t.datwr.integer
                self.display.DrawFramebuffer()
                self.frame_cnt += 1
                print("Frame", self.frame_cnt)
        
    def fb_wb_callback(self, transaction):
        fb = self.back_fb_base
        for t in transaction:
            if (t.adr.integer == 0xFFFFFFFC):
                # fast FB clear
                self.display.ClearFramebuffer()
            elif (t.adr.integer >= fb) and (t.adr.integer < fb + FB_SIZE):
                off = (t.adr.integer - fb) // DISPLAY_BPP
                self.display.PutFragment((off % DISPLAY_SIZE_X, DISPLAY_SIZE_Y-1 - (off // DISPLAY_SIZE_X), 0, t.datwr.integer))
        
    def read(self, addr):
        self.request_queue.put((True, addr))
        return [self.reads_queue.get()]
        
    def write(self, addr, dat):
        assert(len(dat) == 1)
        self.request_queue.put((False, addr, dat[0]))

@cocotb.test()
async def testbech(dut):
    # create Wishbone
    wishbone = WishboneDriver(dut, 0x90000000, (0x40D30000, 0x40C00000))
    
    # launch etherbone server
    server = RemoteServer(wishbone, "127.0.0.1", 1234, 32)
    server.open()
    server.start(4)
    
    await Timer(1000, "ms")
    
            
