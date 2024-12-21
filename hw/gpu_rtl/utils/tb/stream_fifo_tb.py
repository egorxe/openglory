#
# Cocotb testbench for stream FIFO
#

import os
import itertools
import cocotb
import logging
from random import randint
from cocotb.clock import Clock
from cocotb_bus.bus import Bus
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame

PERIOD = 10
TEST_PACKETS = 1000

def cycle_pause():
    return itertools.cycle([0]*randint(1,23) + [1]*randint(1,233) + [0]*randint(1,23) + [1]*randint(1,577) + [0]*randint(1,230) + [1])

# Tester class
class StreamFifoTB:
    def __init__(self, dut):
        self.dut = dut
        
        cocotb.start_soon(Clock(dut.clk_i, PERIOD, units = "ns").start())

        self.axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk_i, dut.rst_i)
        self.axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk_i, dut.rst_i)
        self.axis_sink.set_pause_generator(cycle_pause())
            
        self.axis_sink.log.setLevel(logging.WARNING)
        self.axis_source.log.setLevel(logging.WARNING)
        
    async def reset(self):
        self.dut.rst_i.value = 1
        await Timer(100 * PERIOD, 'ns')
        self.dut.rst_i.value = 0
        print("Reset deasserted")
        
    async def write_to_fifo(self):
        for i in range(TEST_PACKETS):
            test = i*111335577
            length = randint(1,4) * 4
            mask = (256**length) - 1
            await self.axis_source.send(int.to_bytes(test&mask, length=length, byteorder="little"))
            await Timer(PERIOD * randint(0,10), 'ns')
        
    async def read_from_fifo(self):
        for i in range(TEST_PACKETS):
            test = i*111335577
            await Timer(PERIOD * randint(0,100), 'ns')
            frame = await self.axis_sink.recv()
            mask = (256**len(frame)) - 1
            data = int.from_bytes(frame, byteorder="little")
            assert (data == (test&mask))
 

@cocotb.test()
async def stream_fifo_tb(dut):
    tester = StreamFifoTB(dut)

    await tester.reset()
    
    # await tester.write_to_fifo()
    cocotb.start_soon(tester.write_to_fifo())
    await tester.read_from_fifo()
        
