# Generic empty cocotb testbench.
#
# Checks if cocotb_test_complete is present in top level,
# succeeds if this signal becomes 1, and fails on any metavalue (X, Z).
#
# If no such signal - waits for 1 sec & succeeds if simulator is still running.

import cocotb
import struct
from cocotb.clock import Clock
from cocotb.triggers import Timer,Edge

def float32ToBin32Str(num): #can be used with python float
    return ''.join('{:0>8b}'.format(c) for c in struct.pack('!f', num)) #empty bits equal 0, alignement to the right border, 8-bits width; ! - byte order - big endian
    
def float32ToSignal32(num):
    return int(float32ToBin32Str(num), 2)

#signal to pyFloat (actually double in C terms)
def bin32StrToBin64Str(value):
    sign = value[0]
    exponent32int = int(value[1:(8+1)], 2)
    mantissa32 = value[9:(31+1)]
    if (exponent32int == 0 and int(mantissa32, 2) == 0):
        exponent = 0
        exponent64 = "".join("0" for i in range(1, 11))
    else:
        exponent = exponent32int - 127
        exponent64 = "{0:0>11b}".format(exponent + 1023) 
    mantissa64 = mantissa32 + "".join("0" for i in range(1, 30))
    return sign + exponent64 + mantissa64

def bin64StrToFloat64(value):
    return struct.unpack("d", struct.pack("q", int(value, 2)))[0] #packing as long long and unpacking as C-double
    
def intToBin32Str(num):
    return ''.join('{:0>8b}'.format(c) for c in struct.pack('!i', num))

def signFunc(value):
	sign = int(f"{value:032b}"[0], 2) #padding with leading zeroes, 32 positions, binary format
	sign = sign * -2 + 1 # mapping: 0 -> +1, 1 -> -1
	return sign

def absFunc(value):
	return int("0" + f"{value:032b}"[1:], 2) 

#signal - float32 as int
def signal32ToFloat64(value):
	sign = signFunc(value)
	value = absFunc(value)
	return sign * bin64StrToFloat64(bin32StrToBin64Str(intToBin32Str(value))) #due to int expansion in python, absolute value should be taken for numbers larger than 2^31 - 1  
    
PERIOD = 10

@cocotb.test()
async def testbech(dut):
    # check if cocotb_test_complete signal is avaliable at the top
    cocotb.start_soon(Clock(dut.clk_i, PERIOD, units = "ns").start())
    dut.rst_i.value = 1
    dut.stb_i.value = 0
    dut.data_i.value = 0
    await Timer(PERIOD*10, "ns")
    dut.rst_i.value = 0
    # await Timer(PERIOD*10, "ns")
    
    for i in range(10):
        # a = (i-5000)* 0.0037539
        a = (i-5000)* 1e18 + 0.1111
        if a == 0:
            continue
        dut.data_i.value = float32ToSignal32(a)
        dut.stb_i.value = 1
        await Timer(PERIOD, "ns")
        dut.stb_i.value = 0
        # await Timer(PERIOD, "ns")
        while (dut.ready_o.value == 0):
            # await Timer(PERIOD, "ns")
            await cocotb.triggers.RisingEdge(dut.clk_i)
        res = signal32ToFloat64(int(dut.result_o.value))
        expected = 1/a
        print(f'{a:{10}.{10}}', "           ", f'{expected:{10}.{10}}', "        ", f'{res:{10}.{10}}')
        assert(abs(1-(expected/res)) < (1/(2**23)))
        # await Timer(PERIOD, "ns")
            
