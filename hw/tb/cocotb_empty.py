# Generic empty cocotb testbench.
#
# Checks if cocotb_test_complete is present in top level,
# succeeds if this signal becomes 1, and fails on any metavalue (X, Z).
#
# If no such signal - waits for 1 sec & succeeds if simulator is still running.

import cocotb
from cocotb.triggers import Timer,Edge

@cocotb.test()
async def testbech(dut):
    # check if cocotb_test_complete signal is avaliable at the top
    test_complete = None
    try:
        test_complete = dut.cocotb_test_complete
        dut._log.info("cocotb_test_complete signal registered")
    except:
        dut._log.info("No cocotb_test_complete signal is present in HDL testbench, testbench should finish itself and cocotb will fail")
        
    if test_complete == None:
        # just wait for 1 sec
        await Timer(1000, "ms")
    else:
        # check cocotb_test_complete walue
        while test_complete.value == 0:
            await cocotb.triggers.Edge(test_complete)
            dut._log.info("Test complete signal change:" + str(test_complete.value))
        assert test_complete.value == 1
            
