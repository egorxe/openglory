import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame

import struct
import numpy as np
import ctypes as ct
import random as rnd

#parameters
TESTS_AMOUNT = 4
SCREEN_WIDTH = 640
SCREEN_HEIGHT = 480

#configuration
N_COORDS = 3
N_WCOORDS = N_COORDS + 1
N_COLORS = 4
WRD_P_VRTX = N_COORDS + N_COLORS
WRD_P_WVRTX = N_WCOORDS + N_COLORS
VRTX_P_PLGN = 3
WRD_P_PLGN = WRD_P_VRTX*VRTX_P_PLGN + 1
WRD_P_WPLGN = WRD_P_WVRTX*VRTX_P_PLGN + 1
WRD_P_MTRX = 4*4
BYTES_PER_WORD = 4
GPU_PIPE_CMD_POLY_VERTEX = int("FFFFFF00", 16)
GPU_PIPE_CMD_FRAME_END = int("FFFFFF01", 16)
GPU_PIPE_CMD_FRAGMENT = int("FFFFFF02", 16)
GPU_PIPE_CMD_MODEL_MATRIX = int("FFFFFF03", 16)
TOLERANCE = 1e-3

#data structures
class Point:
	def __init__(self, x, y, z, r, g, b, alpha):
		self.x = x
		self.y = y
		self.z = z
		self.r = r
		self.g = g
		self.b = b
		self.alpha = alpha

class Polygon:
	def __init__(self, p1, p2, p3):
		self.p1 = p1
		self.p2 = p2
		self.p3 = p3

###conversion functions
#common
def float32ToBin32Str(num):
	return ''.join('{:0>8b}'.format(c) for c in struct.pack('!f', num)) #empty bits equal 0, alignement to the right border, 8-bits width

def intToBin32Str(num):
	return ''.join('{:0>8b}'.format(c) for c in struct.pack('!i', num))

#pyFloat and int (actually double in C terms) to signal
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

#for AXI-Stream
def intToBytes(i):
    return (i).to_bytes(BYTES_PER_WORD, byteorder='little')

def bytesToInt(f):
    return int.from_bytes(f, byteorder='little', signed=False)

#for human reading
def intToBytesBigEndian(i):
    return (i).to_bytes(BYTES_PER_WORD, byteorder='big')

def bytesToIntBigEndian(f):
    return int.from_bytes(f, byteorder='big', signed=False)

#tester class
class Vt_axi_tester:
	def __init__(self, dut):
		self.dut = dut;
		self.received_frames = 0
		self.received_words = 0
		self.n_words_to_receive = 0
		self.sent_data = [] #float as signal32
		self.received_data = [] #float as signal32
		self.sent_point_buf = (ct.c_float * 3)() 
		self.processed_point = (ct.c_float * 4)()
		self.model_matrix = (ct.c_float * 16)()
		self.setModelMatrix([
								1., .0, .0, .0,
								.0, 1., .0, .0,
								.0, .0, 1., -3.0,
								.0, .0, .0, 1.
							])

		cocotb.start_soon(Clock(dut.clk_i, 10, units = "ns").start())

		self.axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk_i, dut.rst_i)
		self.axis_monitor = AxiStreamMonitor(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk_i, dut.rst_i)
		self.axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk_i, dut.rst_i)

	def printMatrix(self, matrix):
		for i in range(4):
			for j in range(4):
				print(matrix[i*4 + j], end=" ")
			print("")

	def setModelMatrix(self, matrix):
		#self.model_matrix = matrix
		print("Model matrix setting...")
		for i in range(4):
			for j in range(4):
				self.model_matrix[i*4 + j] = ct.c_float(matrix[i*4 + j])
		print("Model matrix was set, type:", type(self.model_matrix))
		self.printMatrix(self.model_matrix)

	async def setSigForOneTact(self, signal, value):
		signal.value = value
		await RisingEdge(self.dut.clk_i)

	async def reset(self):
		await RisingEdge(self.dut.clk_i)
		await self.setSigForOneTact(self.dut.rst_i, 1)
		await self.setSigForOneTact(self.dut.rst_i, 0)
		print("Module was reseted")

	async def sendSignal32(self, data, with_resp=False):
		frame = AxiStreamFrame(intToBytes(data), tuser = 0, tdest = 0)
		self.sent_data.append(data)
		await self.axis_source.send(frame)
		if with_resp:
			self.n_words_to_receive += 1
		print(intToBytes(data), "was sent")

	async def sendFloat(self, data, with_resp=False):
		await self.sendSignal32(float32ToSignal32(data), with_resp)

	async def sendVertice(self, point):
		print(f"Sending point...")
		await self.sendFloat(point.x, True)
		await self.sendFloat(point.y, True)
		await self.sendFloat(point.z, True)
		self.n_words_to_receive += 1 #weight
		await self.sendFloat(point.r, True)
		await self.sendFloat(point.g, True)
		await self.sendFloat(point.b, True)
		await self.sendFloat(point.alpha, True)
		print("Point was sent")

	async def sendPolygon(self, polygon):
		print("Sending polygon...")
		await self.sendSignal32(GPU_PIPE_CMD_POLY_VERTEX, True)
		await self.sendVertice(polygon.p1)
		await self.sendVertice(polygon.p2)
		await self.sendVertice(polygon.p3)
		print("Polygon was sent")

	async def sendModelMatrix(self, matrix):
		print("Sending model matrix...")
		await self.sendSignal32(GPU_PIPE_CMD_MODEL_MATRIX)

		for i in range(4):
			for j in range(4):
				await self.sendFloat(matrix[i*4 + j])
		print("Model matrix was sent")

	async def startReception(self):
		while True:
			frame = await self.axis_sink.read()
			wordAsStr = ""
			byte_num = 0
			
			for byte in frame:
				wordAsStr = (intToBin32Str(byte))[24:32] + wordAsStr #order of concatenation matters
				print(intToBin32Str(byte)[24:32])
				byte_num += 1

				if (byte_num % BYTES_PER_WORD == 0):
					word = int(wordAsStr, 2)
					self.received_words += 1
					self.received_data.append(word)
					print(wordAsStr, hex(word), "was received,", self.received_words, "words were received at all")
					wordAsStr =  ""

			self.received_frames += 1
			print(frame, "was received,", self.received_frames, "frames were received at all,", self.received_frames//4, "polygons were received at all")

	def checkEquality(self, expected_value, got_value, msg=None):
		print("got", got_value, "expected", expected_value, end='')
		assert got_value == expected_value, msg

	def checkPolygon(self, sentPtr, recPtr):
		vertex_transform = ct.CDLL('./vertex_transform.so')
		process_vertex = vertex_transform.ProcessVertex
		process_vertex.argtypes= [ct.POINTER(ct.c_float), ct.POINTER(ct.c_float), ct.POINTER(ct.c_float), ct.c_int, ct.c_int]
		
		print("Start code expected", hex(self.sent_data[sentPtr]), "received", hex(self.received_data[recPtr]))
		assert self.received_data[recPtr] == self.sent_data[sentPtr], "GPU_PIPE_CMD_POLY_VERTEX wasn't transmitted"
		sentPtr += 1
		recPtr += 1

		#points checking
		for pointCnt in range(3):
			print("Point", pointCnt)
			for i in range(3):
				self.sent_point_buf[i] = (ct.c_float)(signal32ToFloat64(self.sent_data[sentPtr]))
				sentPtr += 1
			
			#vertices processing in C code
			process_vertex(ct.cast(self.sent_point_buf, ct.POINTER(ct.c_float)), 
							ct.cast(self.processed_point, ct.POINTER(ct.c_float)),
							ct.cast(self.model_matrix, ct.POINTER(ct.c_float)),
                            SCREEN_WIDTH,
                            SCREEN_HEIGHT
							)
				
			#coordinates checking
			for i in range(4):
				print("coordinate", i, 
						"got", signal32ToFloat64(self.received_data[recPtr]), hex(self.received_data[recPtr]), 
						"expected", self.processed_point[i], hex(float32ToSignal32(self.processed_point[i]))
						)
				# assert self.received_data[recPtr] == float32ToSignal32(self.processed_point[i]), \
				# 		"Answers are different"
				assert np.abs(signal32ToFloat64(self.received_data[recPtr]) - self.processed_point[i]) <= TOLERANCE, \
						"Answers are different"
				#last symbol may be different
				# assert hex(self.received_data[recPtr])[:-2] == hex(float32ToSignal32(self.processed_point[i]))[:-2], \
						# "Answers are different" 
				recPtr += 1

			#colors checking
			for i in range(4):
				print("color", i,
						"got",  signal32ToFloat64(self.received_data[recPtr]), hex(self.received_data[recPtr]),
						"expected",  signal32ToFloat64(self.sent_data[sentPtr]), hex(self.sent_data[sentPtr]))
				assert self.received_data[recPtr] == self.sent_data[sentPtr], \
						"Answers are different"
				sentPtr += 1
				recPtr += 1

			print("");

		return sentPtr, recPtr

	async def checkReception(self):
		while self.received_words != self.n_words_to_receive:
			await RisingEdge(self.dut.clk_i)

		polyCnt = 1;
		sentPtr = 0;
		recPtr = 0;
		while sentPtr < len(self.sent_data):
			if self.sent_data[sentPtr] == GPU_PIPE_CMD_POLY_VERTEX:
				print("Test of polygon number", polyCnt, "from", TESTS_AMOUNT, "is started\n")
				sentPtr, recPtr = self.checkPolygon(sentPtr, recPtr)
				print("Test of polygon number", polyCnt, "from", TESTS_AMOUNT, "is complete\n")
				polyCnt += 1

			elif self.sent_data[sentPtr] == GPU_PIPE_CMD_MODEL_MATRIX:
				sentPtr += 1
				# matrix = [signal32ToFloat64(self.sent_data[sentPtr + i]) for i in range(WRD_P_MTRX)]
				# sentPtr += WRD_P_MTRX

				matrix = []
				for i in range(WRD_P_MTRX):
					matrix.append(signal32ToFloat64(self.sent_data[sentPtr]))
					sentPtr += 1
				
				self.setModelMatrix(matrix)
			
			else:
				print("Unknown word: got", hex(self.received_data[recPtr]), 
						"expected", hex(self.sent_data[sentPtr]))
				assert self.received_data[recPtr] == self.sent_data[sentPtr], \
						"Answers are different"
				sentPtr += 1
				recPtr += 1

def randVal(magnitude=10):
	return (rnd.random()*2 - 1)*magnitude

def randPoint(magnitude=10):
	return Point(*[randVal(magnitude) for i in range(7)])

def randPolygon(magnitude=10):
	return Polygon(*[randPoint(magnitude) for i in range(3)])

def randMatrix(magnitude=10):
	return [randVal(magnitude) for i in range(16)]

#testbench
@cocotb.test()
async def testbech(dut):
	print ("Simulation started")
	rnd.seed()

	tester = Vt_axi_tester(dut)
	await tester.reset()

	cocotb.start_soon(tester.startReception())

	#testing process
	for i in range(TESTS_AMOUNT):
		print(f"Model matrix {i} sending...")
		await tester.sendModelMatrix(randMatrix(10))
		print(f"Model matrix {i} was sent")

		print(f"Polygon {i} sending...")
		await tester.sendPolygon(randPolygon(10))
		print(f"Polygon {i} was sent")

		#just check that vertex_transform passes irrelevant codewords
		if (i == 1):
			await tester.sendSignal32(GPU_PIPE_CMD_FRAME_END, True)
			await tester.sendSignal32(GPU_PIPE_CMD_FRAGMENT, True)
			

	await tester.checkReception();
	print("Simulation finished")
