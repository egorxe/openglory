import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame
from cocotb.result import TestFailure, TestSuccess

import ctypes as ct
import random as rnd

import conversions as conv

SCREEN_WIDTH = 640
SCREEN_HEIGHT = 480

BYTES_PER_WORD = 4
GPU_PIPE_CMD_POLY_VERTEX = int("FFFFFF00", 16)
GPU_PIPE_CMD_FRAME_END = int("FFFFFF01", 16)
GPU_PIPE_CMD_FRAGMENT = int("FFFFFF02", 16)
ZERO32 = int("00000000", 16)
FINISH_TEST_CODE = int("FFFFFFFF", 16)

Z_TOLERANCE_PCT = 10
Z_TOLERANCE_THRESHOLD = 100
COLOR_TOLERANCE = 1

def cmd2Str(cmd):
    if (cmd == GPU_PIPE_CMD_POLY_VERTEX):
        return "GPU_PIPE_CMD_POLY_VERTEX"
    elif (cmd == GPU_PIPE_CMD_FRAME_END):
        return "GPU_PIPE_CMD_FRAME_END"
    elif (cmd == GPU_PIPE_CMD_FRAGMENT):
        return "GPU_PIPE_CMD_FRAGMENT"
    else:
        return hex(cmd)

def isCmd(x):
    if (x == GPU_PIPE_CMD_POLY_VERTEX or x == GPU_PIPE_CMD_FRAME_END or x == GPU_PIPE_CMD_FRAGMENT):
        return True
    else:
        return False

#data structures
class WPoint:
    def __init__(self, x, y, z, w, r, g, b, alpha):
        self.x = x
        self.y = y
        self.z = z
        self.w = w
        self.r = r
        self.g = g
        self.b = b
        self.alpha = alpha

class WPolygon:
    def __init__(self, p1, p2, p3):
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3

class rasterizer_axis_tester:
    def __init__(self, dut):
        self.dut = dut
        self.received_frames = 0
        self.received_words_amount = 0
        self.received_data = [] #int as signal32
        self.sent_data = [] #float32 as signal32
        self.sent_words_amount = 0
        self.polygon = (ct.c_float * 24)()
        self.fragments = (ct.c_uint * (5 * 100000))() #multiplication order defines dimension of array

        cocotb.start_soon(Clock(dut.clk_i, 10, units = "ns").start())

        self.axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk_i, dut.rst_i)
        self.axis_monitor = AxiStreamMonitor(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk_i, dut.rst_i)
        self.axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk_i, dut.rst_i)

    async def setSigForOneTact(self, signal, value):
        signal.value = value
        await RisingEdge(self.dut.clk_i)

    async def reset(self):
        await RisingEdge(self.dut.clk_i)
        await self.setSigForOneTact(self.dut.rst_i, 1)
        await self.setSigForOneTact(self.dut.rst_i, 0)
        print("Module was reseted")

    async def sendSignal32(self, data):
        frame = AxiStreamFrame(conv.intToBytes(data), tuser = 0, tdest = 0)
        self.sent_data.append(data)
        self.sent_words_amount += 1
        await self.axis_source.send(frame)
        print(conv.intToBytes(data), "was sent")

    async def sendFloat32(self, data):
        await self.sendSignal32(conv.float32ToSignal32(data))

    async def sendFloat(self, data):
        await self.sendSignal32(conv.float32ToSignal32(data))

    async def sendWVertice(self, point):
        await self.sendFloat(point.x)
        await self.sendFloat(point.y)
        await self.sendFloat(point.z)
        await self.sendFloat(point.w)
        await self.sendFloat(point.r)
        await self.sendFloat(point.g)
        await self.sendFloat(point.b)
        await self.sendFloat(point.alpha)
        print("WPoint was sent")

    async def sendWPolygon(self, polygon):
        await self.sendSignal32(GPU_PIPE_CMD_POLY_VERTEX)
        await self.sendWVertice(polygon.p1)
        await self.sendWVertice(polygon.p2)
        await self.sendWVertice(polygon.p3)
        print("WPolygon was sent")

    async def startReception(self):
        while True:
            print("waiting frame")
            frame = await self.axis_sink.read()
            print("got frame")
            wordAsStr = ""
            byte_num = 0
            
            for byte in frame:
                wordAsStr = (conv.intToBin32Str(byte))[24:32] + wordAsStr #order of concatenation matters
                print(conv.intToBin32Str(byte)[24:32])
                byte_num += 1

                if (byte_num % BYTES_PER_WORD == 0):
                    word = int(wordAsStr, 2)
                    self.received_words_amount += 1
                    self.received_data.append(word)
                    print(wordAsStr, hex(word), "was received,", self.received_words_amount, "words were received at all")
                    wordAsStr =  ""

            self.received_frames += 1
            print(frame, "was received,", self.received_frames, "frames were received at all")

    async def checkReception(self):
        print("Start of checking")
        rasterizer = ct.CDLL('./rasterizer.so')
        rasterize = rasterizer.rasterize
        rasterize.argtypes = [ct.POINTER(ct.c_float), ct.POINTER(ct.c_uint), ct.c_int, ct.c_int]
        rasterize.restype = ct.c_int

        #waiting while module processes data
        while self.received_words_amount < 2:
            await RisingEdge(self.dut.clk_i)

        while self.received_data[-2] != FINISH_TEST_CODE or self.received_data[-1] != ZERO32:
            await RisingEdge(self.dut.clk_i)

        #checking
        polygonsChecked = 0
        checked_received_words = 0
        i = 0
        while i < self.sent_words_amount:
            if (not isCmd(self.sent_data[i])):
                print("Checking sent word #", i , ":", hex(self.sent_data[i]))
            else:
                print("Checking sent word #", i , ":", cmd2Str(self.sent_data[i]))

            if (self.sent_data[i] == GPU_PIPE_CMD_POLY_VERTEX):
                print("\nChecking polygon #", polygonsChecked, sep = '')
                for j in range(24):
                    self.polygon[j] = (ct.c_float)(conv.signal32ToFloat64(self.sent_data[i + 1 + j]))

                
                #self.polygon processing in C code
                fragmentsAmount = rasterize(ct.cast(self.polygon, ct.POINTER(ct.c_float)), 
                                            ct.cast(self.fragments, ct.POINTER(ct.c_uint)), 
                                            SCREEN_WIDTH,
                                            SCREEN_HEIGHT)
                print("Fragments to check:", fragmentsAmount)

                for j in range(fragmentsAmount):
                    print("Fragment #", j, ":", sep = '')
                    print("Got:", end = ' ')
                    for k in range(5):
                        print(hex(self.received_data[checked_received_words + j*5 + k]), end = ' ')
                    print(' (', end = '')
                    for k in range(5):
                        print(self.received_data[checked_received_words + j*5 + k], end = ' ')
                    print(')')

                    print("Expected:", end = ' ')
                    for k in range(5):
                        print(hex(self.fragments[j*5 + k]), end = ' ')
                    print(' (', end = '')
                    for k in range(5):
                        print(self.fragments[j*5 + k], end = ' ')
                    print(')')

                    for k in range(5):
                        if k < 3:
                            assert hex(self.received_data[checked_received_words + j*5 + k]) == hex(self.fragments[j*5 + k]), \
                                "Answers are different:" + hex(self.received_data[checked_received_words + j*5 + k]) + " != " + hex(self.fragments[j*5 + k])
                        elif k == 3:
                            z_module = self.received_data[checked_received_words + j*5 + k]
                            z_true = self.fragments[j*5 + k]
                            if abs(z_true) >= Z_TOLERANCE_THRESHOLD:
                                is_right = abs((z_module - z_true)/z_true)*100 <= Z_TOLERANCE_PCT
                            else:
                                is_right = abs((z_module - z_true)) <= Z_TOLERANCE_THRESHOLD
                            assert is_right, "Answers are different:" + hex(z_module) + " != " + hex(z_true)
                        else:
                            argb_module = conv.intToBin32Str(self.received_data[checked_received_words + j*5 + k])
                            argb_true = conv.intToBin32Str(self.fragments[j*5 + k])
                            a_module = int(argb_module[0:8], 2)
                            r_module = int(argb_module[8:16], 2)
                            g_module = int(argb_module[16:24], 2)
                            b_module = int(argb_module[24:32], 2)
                            a_true = int(argb_true[0:8], 2)
                            r_true = int(argb_true[8:16], 2)
                            g_true = int(argb_true[16:24], 2)
                            b_true = int(argb_true[24:32], 2)
                            assert abs(a_module - a_true) <= COLOR_TOLERANCE and abs(r_module - r_true) <= COLOR_TOLERANCE and abs(g_module - g_true) <= COLOR_TOLERANCE and abs(b_module - b_true) <= COLOR_TOLERANCE, \
                                "Answers are different:" + hex(self.received_data[checked_received_words + j*5 + k]) + " != " + hex(self.fragments[j*5 + k])

                checked_received_words += fragmentsAmount*5;
                i += 25
                polygonsChecked += 1

            else:
                print("Got:", cmd2Str(self.received_data[checked_received_words]), end = " ")
                print("(next words:", end = " ")
                print([cmd2Str(x) for x in self.received_data[checked_received_words + 1: checked_received_words + 5]])
                print(")")
                print("Expected:", cmd2Str(self.sent_data[i]))
                assert self.received_data[checked_received_words] ==  self.sent_data[i]
                print("Got:", hex(self.received_data[checked_received_words + 1]))
                print("Expected:", hex(ZERO32))
                assert self.received_data[checked_received_words + 1] == ZERO32
                checked_received_words += 2
                i += 1

        raise TestSuccess("Success")

@cocotb.test()
async def testbench(dut):
    # rnd.seed()

    tester = rasterizer_axis_tester(dut)
    await tester.reset()
    cocotb.start_soon(tester.startReception())

    for i in range(5):
        xyampl = 5 #set something little to save time
        zampl = 5
        wampl = 5
        x = (SCREEN_WIDTH - 1)/2
        y = (SCREEN_HEIGHT - 1)/2
        pointR = WPoint(x,                              y,                           rnd.random()*zampl,     rnd.random()*wampl + 1, rnd.random(), rnd.random(), rnd.random(), rnd.random())
        pointG = WPoint(x + rnd.random()*xyampl,        y + rnd.random()*xyampl,     rnd.random()*zampl,     rnd.random()*wampl + 1, rnd.random(), rnd.random(), rnd.random(), rnd.random())
        pointB = WPoint(x + rnd.random()*xyampl,        y + rnd.random()*xyampl,     rnd.random()*zampl,     rnd.random()*wampl + 1, rnd.random(), rnd.random(), rnd.random(), rnd.random())
        # pointR = WPoint(250.0,                          250.0,                      0.1,                    rnd.random()*wampl + 1, rnd.random(), rnd.random(), rnd.random(), rnd.random())
        # pointG = WPoint(250.0,                          253.5,                      0.1,                    rnd.random()*wampl + 1, rnd.random(), rnd.random(), rnd.random(), rnd.random())
        # pointB = WPoint(253.5,                          250.0,                      0.1,                    rnd.random()*wampl + 1, rnd.random(), rnd.random(), rnd.random(), rnd.random())
        # pointR = WPoint(x,                           y,                           rnd.random()*zampl,     1, 0, 0, 1, 0.0)
        # pointG = WPoint(x + rnd.random()*xyampl,     y + rnd.random()*xyampl,     rnd.random()*zampl,     1, 0, 0, 1, 0.0)
        # pointB = WPoint(x + rnd.random()*xyampl,     y + rnd.random()*xyampl,     rnd.random()*zampl,     1, 0, 0, 1, 0.0)
        # pointR = WPoint(250.0,                       250.0,                       0.1,                    1, 1, 0, 0, 0.0)
        # pointG = WPoint(250.0,                       253.5,                       0.1,                    1, 0, 1, 0, 0.0)
        # pointB = WPoint(253.5,                       250.0,                       0.1,                    1, 0, 0, 1, 0.0)
        testPolygon = WPolygon(pointR, pointG, pointB)
        await tester.sendWPolygon(testPolygon)
        await tester.sendSignal32(GPU_PIPE_CMD_FRAME_END)

    await tester.sendSignal32(FINISH_TEST_CODE)
    await tester.checkReception()


