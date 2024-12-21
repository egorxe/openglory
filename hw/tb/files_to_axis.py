#
# Cocotb testbench reading input file into AXI-Stream and writing output
# stream into file.
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

def cycle_pause():
    return itertools.cycle([0]*randint(1,23) + [1]*randint(1,233) + [0]*randint(1,23) + [1]*randint(1,577) + [0]*randint(1,230) + [1])

# Tester class
class Files2AXIS:
    def __init__(self, dut):
        self.dut = dut
        
        cocotb.start_soon(Clock(dut.clk_i, 10, units = "ns").start())
        
        self.axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk_i, dut.rst_i)
        self.axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk_i, dut.rst_i)
        if ("AXIS_DELAY" in os.environ) and (os.environ["AXIS_DELAY"] == 1):
            self.axis_sink.set_pause_generator(cycle_pause())
            
        self.axis_sink.log.setLevel(logging.WARNING)
        self.axis_source.log.setLevel(logging.WARNING)
        
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
        
    async def write_output(self, f):
        while True:
            f.write((await self.axis_sink.recv()).tdata)
            f.flush()
 

# AXIS to file testbench
@cocotb.test()
async def files_to_axis(dut):
    print ("Files <=> AXI-stream wrapper started")
    
    tester = Files2AXIS(dut)

    await tester.reset()
    
    cocotb.start_soon(tester.write_output(open(os.environ["OUTPUT_FILE"], "wb")))
    await tester.read_input(open(os.environ["INPUT_FILE"], "rb"))
        
