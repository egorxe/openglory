import struct

BYTES_PER_WORD = 4 #standart word width = 32

def float32ToBin32Str(num): #can be used with python float
    return ''.join('{:0>8b}'.format(c) for c in struct.pack('!f', num)) #empty bits equal 0, alignement to the right border, 8-bits width; ! - byte order - big endian

def float64ToBin64Str(num):
    return ''.join('{:0>8b}'.format(c) for c in struct.pack('!d', num)) #empty bits equal 0, alignement to the right border, 8-bits width; ! - byte order - big endian

def intToBin32Str(num):
    return ''.join('{:0>8b}'.format(c) for c in struct.pack('!i', num))

#pyFloat and int (actually double in C terms) to signal
def float32ToSignal32(num):
    return int(float32ToBin32Str(num), 2)

def float64ToSignal64(num):
    return int(float64ToBin64Str(num), 2)

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

#signal - float32 as int
def signal32ToFloat64(value):
    return bin64StrToFloat64(bin32StrToBin64Str(intToBin32Str(value)))

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
