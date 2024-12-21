#
# Cocotb testbench for fragment stage reading input file into AXI-Stream 
# and writing output stream plus WB acceses into file. 
# Based on files_to_axis.py
#

import os
import itertools
import cocotb
import logging
import os
from random import randint
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame
from cocotbext.wishbone.monitor import WishboneSlave
from cocotbext.wishbone.driver import WBOp
from itertools import repeat

WBS_SIGNALS_DICT ={"cyc":  "cyc_o",
                  "stb":  "stb_o",
                  "we":   "we_o",
                  "adr":  "adr_o",
                  "datwr":"dat_o",
                  "datrd":"dat_i",
                  "ack":  "ack_i" }

SCREEN_WIDTH    = 640
SCREEN_HEIGHT   = 480                  
FB_OFFSET       = 0x80000 
MEMORY_SIZE     = FB_OFFSET*3

def int_to_bytes(i):
    # small helper
    return int.to_bytes(i, length=4, byteorder='little')

def stream_cycle_pause():
    return itertools.cycle([0]*randint(1,23) + [1]*randint(1,233) + [0]*randint(1,23) + [1]*randint(1,577) + [0]*randint(1,230) + [1])

# Tester class
class Files2Fragment:
    def __init__(self, dut, outfile):
        self.dut = dut
        self.of = outfile
        
        # cocotb.start_soon(Clock(dut.clk_i, 10, units = "ns").start())
        
        self.axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk_i, dut.rst_i)
        self.axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk_i, dut.rst_i)
        if ("AXIS_DELAY" in os.environ) and (os.environ["AXIS_DELAY"] == 1):
            self.axis_sink.set_pause_generator(stream_cycle_pause())
            
        self.axis_sink.log.setLevel(logging.WARNING)
        self.axis_source.log.setLevel(logging.WARNING)
        
        self.frag_wb = WishboneSlave(self.dut, "frag_wb", dut.clk_i, width = 32, signals_dict = WBS_SIGNALS_DICT, waitreplygen=repeat(1), datgen=self.frag_mem_read())
        self.frag_wb.add_callback(self.frag_mem_callback)
        self.fb_wb = WishboneSlave(self.dut, "fb_wb", dut.clk_i, width = 32, signals_dict = WBS_SIGNALS_DICT, waitreplygen=repeat(1), datgen=self.fb_mem_read())
        self.fb_wb.add_callback(self.fb_mem_callback)
        
        self.wb_mem = [0] * MEMORY_SIZE
        
    async def reset(self):
        self.dut.rst_i.value = 1
        await Timer(1000, 'ns')
        self.dut.rst_i.value = 0
        print("Reset deasserted")
        
    async def read_input(self, f):
         # make file non blocking
        fd = f.fileno()
        os.set_blocking(fd, False)
        
        while True:
            try:
                b = os.read(fd, 4)
                frame = AxiStreamFrame(b)
                await self.axis_source.send(frame)
                await self.axis_source.wait()
            except BlockingIOError as e:
                # when there is no data to read - just run simulation for some time
                await Timer(1000, 'ns')
        
    async def write_output(self):
        while True:
            self.of.write((await self.axis_sink.recv()).tdata)
            self.of.flush()
            
    def frag_mem_read(self):
        while True:
            adr = self.frag_wb.bus.adr.value.integer
            yield self.wb_mem[adr]
            
    def fb_mem_read(self):
        while True:
            adr = self.fb_wb.bus.adr.value.integer
            yield self.wb_mem[adr]
            
    def frag_mem_callback(self, transaction):
        for t in transaction:
            if (t.datwr):
                if t.adr.integer == (2**32)-1:
                    # fast clear
                    for a in range(0,FB_OFFSET):
                        self.wb_mem[a] = 0x00FFFFFF
                else:
                    self.wb_mem[t.adr.integer] = t.datwr.integer
    
    def fb_mem_callback(self, transaction):
        for t in transaction:
            if (t.datwr):
                adr = t.adr.integer
                if adr == (2**32)-1:
                    # fast clear
                    for a in range(FB_OFFSET, len(self.wb_mem)):
                        self.wb_mem[a] = 0
                    f.write(int_to_bytes(0xFFFF0011))
                else:
                    dat = t.datwr.integer
                    self.wb_mem[adr] = dat
                    # on FB write send fragment to file for emulator
                    y = SCREEN_HEIGHT-1 - ((adr - FB_OFFSET) // SCREEN_WIDTH)
                    x = (adr - FB_OFFSET) % SCREEN_WIDTH
                    self.of.write(int_to_bytes(0xFFFF0320))
                    self.of.write(int_to_bytes(y << 16 | x))
                    self.of.write(int_to_bytes(0))
                    self.of.write(int_to_bytes(dat))
                    self.of.flush()
 

# AXIS to file testbench
@cocotb.test()
async def files_to_fragment(dut):
    print ("Files <=> Fragment stage wrapper started")
    
    tester = Files2Fragment(dut, open(os.environ["OUTPUT_FILE"], "wb"))

    await tester.reset()
    
    cocotb.start_soon(tester.write_output())
    await tester.read_input(open(os.environ["INPUT_FILE"], "rb"))
        
