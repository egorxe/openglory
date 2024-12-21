# Cocotb testbench for flushable cache
#

import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotbext.wishbone.driver import WishboneMaster
from cocotbext.wishbone.monitor import WishboneSlave
from cocotbext.wishbone.driver import WBOp
from itertools import repeat
import random

WBM_SIGNALS_DICT ={"cyc":  "cyc",
                  "stb":  "stb",
                  "we":   "we",
                  "adr":  "adr",
                  "datwr":"do",
                  "datrd":"di",
                  "ack":  "ack" }
                  
PERIOD = 10

MEMORY_SIZE     = 1024*2
MEMORY_COEF     = 4 # SLAVE_SIZE/MASTER_SIZE
MST_MEMORY_SIZE = MEMORY_SIZE*MEMORY_COEF

TEST_COUNT          = 300000
PROBABILITY_INV     = 0.00005
PROBABILITY_READ    = 0.60

class WishboneDriver:
    def __init__(self, dut):
        self.dut = dut
        cocotb.start_soon(Clock(dut.sys_clk, PERIOD, units = "ns").start())
        self.clk = self.dut.sys_clk
        self.wbm = WishboneMaster(self.dut, "wb_mst", self.clk, width = 32, timeout = 10000, signals_dict = WBM_SIGNALS_DICT)
        self.wbs = WishboneSlave(self.dut, "wb_slv", self.clk, width = 32*MEMORY_COEF, signals_dict = WBM_SIGNALS_DICT, waitreplygen=repeat(3), datgen=self.wb_mem_read())
        self.wbs.add_callback(self.wb_mem_callback)
        
        self.wb_slv_mem = [0] * MEMORY_SIZE
        self.wb_ref_mem = [0] * MST_MEMORY_SIZE
        
    async def reset(self):
        self.dut.sys_rst.value = 1
        self.dut.inv.value = 0
        await Timer(PERIOD*10, "ns")
        self.dut.sys_rst.value = 0
        
    async def invalidate_and_check(self):
        self.dut._log("Invalidating and checking...")
        # invalidate
        self.dut.inv.value = 1
        await Timer(PERIOD, "ns")
        self.dut.inv.value = 0
        # perform read to wait until invalidation complete
        await self.wb_mst_read(0)
        # verify memory contents
        for i in range(MEMORY_SIZE):
            for c in range(MEMORY_COEF):
                assert(((self.wb_slv_mem[i] >> (32*(MEMORY_COEF-1-c))) & 0xFFFFFFFF) == self.wb_ref_mem[i*MEMORY_COEF + c])
        
    async def test_cache(self):
        for i in range(TEST_COUNT):
            if ((i % 1000) == 0):
                self.dut._log("Bus access", i)
            r = random.uniform(0, 1)
            addr = random.randint(0, MST_MEMORY_SIZE-1)
            if (r < PROBABILITY_INV):
                await self.invalidate_and_check()
            elif (r < PROBABILITY_READ):    
                await self.wb_mst_read(addr)
            else:
                await self.wb_mst_write(addr, random.randint(0, 0xFFFFFFFF))
            
        # check mem contents at the end
        await self.invalidate_and_check()
            
        
    async def wb_mst_read(self, addr):
        wbres = await self.wbm.send_cycle([WBOp(adr=addr)]) 
        return wbres[0].datrd
        
    async def wb_mst_write(self, addr, dat):
        wbres = await self.wbm.send_cycle([WBOp(adr=addr, dat=dat)]) 
        self.wb_ref_mem[addr] = dat
        
    def wb_mem_read(self):
        while True:
            adr = self.wbs.bus.adr.value.integer
            yield self.wb_slv_mem[adr]
        
    def wb_mem_callback(self, transaction):
        for t in transaction:
            if (t.datwr):
                self.wb_slv_mem[t.adr.integer] = t.datwr.integer

@cocotb.test()
async def testbech(dut):
    # random.seed(0)
    wishbone = WishboneDriver(dut)
    await wishbone.reset()
    await wishbone.test_cache()
    
            
