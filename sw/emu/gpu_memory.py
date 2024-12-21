import time
import sys
import os
import mmap
from threading import Thread, Event

from gpu_defs import *

try:
    GENERATE_TB = os.environ["GENERATE_TB"]
except:
    GENERATE_TB = None

class GpuMemory():

    def __init__(self, size, fifo_name, pipe):
        self.size = size
        self.fifo_name = fifo_name
        self.pipe = pipe
        
        self.cmd_size = 0
        self.cmd_base = 0
        self.sync_count = 0
        
        self.terminate = Event()
        self.terminate.clear()
        self.readbuf_thread_flag = 0
        self.readbuf_start = Event()
        self.readbuf_done = Event()
        self.readbuf_done.clear()
        self.readbuf_start.clear()
        self.clear_zbuf = Event()
        self.clear_zbuf.clear()
        self.readbuf_thread = Thread(target = self.ReadBufThread, daemon = False)
        self.readbuf_thread.start()
        
        self.mem = self.get_shared(size)
        
        if GENERATE_TB:
            self.hex_file = open("cmd.hex", "w")
        
    def __del__(self):
        self.close()
        
    def open(self):
        self.fifo = open(self.fifo_name, "wb")
        
    def close(self):
        self.terminate.set()
        self.readbuf_thread.join()
        if self.fifo:
            self.fifo.close()
            
    def get_shared(self, size=1024, name="oglory_shm"):
        fd = os.memfd_create(name, 0)
        os.ftruncate(fd, size)
        m = mmap.mmap(fd, size)
        # os.close(fd)
        return m
        
    def read_mem_word(self, addr):
        return int.from_bytes(self.mem[addr:addr+4], "little")
        
    def write_mem_word(self, addr, data):
        self.mem[addr:addr+4] = data.to_bytes(4, "little")
        
    def read(self, addr):
        self.pipe.pipe_ready.wait()
        # check threads
        if self.readbuf_done.is_set():
            self.readbuf_done.clear()
            self.readbuf_thread_flag = 0
        
        if (addr & GPU_BASE_MASK == GPU_REGS_BASE):
            # GPU register access
            reg_addr = addr & GPU_ADDR_MASK
            if reg_addr == GPU_REG_STAT_OFF:
                # status reg
                sync_bit = int(self.sync_count != self.pipe.sync_count) << 2
                readbuf_bit = self.readbuf_thread_flag
                busy_bit = self.readbuf_thread_flag << 3
                return [sync_bit | readbuf_bit | busy_bit]
            elif reg_addr == GPU_REG_CAP_OFF:
                # capabilities reg
                return [(self.HasLighting() << GPU_CAP_LIGHTING)]
            elif reg_addr == GPU_REG_BOARD0_OFF:
                # board word 0
                return [0x6C756D45]
            elif reg_addr == GPU_REG_BOARD1_OFF:
                # board word 1
                return [0x726F7461]
            else:
                raise ValueError("Incorrect register read via Etherbone:", hex(addr))
        elif (addr & GPU_BASE_MASK == GPU_MEMBUF_BASE):
            # GPU memory access
            return [self.read_mem_word((addr & GPU_ADDR_MASK))]
        else:
            raise ValueError("Incorrect address read via Etherbone:", hex(addr))
        
    def write(self, addr, data):
        self.pipe.pipe_ready.wait()
        assert(len(data) == 1)
        dat = data[0]
        
        if (addr & GPU_BASE_MASK == GPU_REGS_BASE):
            # GPU register access
            reg_addr = addr & GPU_ADDR_MASK
            if reg_addr == GPU_REG_CTRL_OFF:
                # command reg
                if dat & GPU_CTRL_FBSWITCH:
                    self.pipe.NextFrame()
            elif reg_addr == GPU_REG_CMDSIZE_OFF:
                assert(self.readbuf_thread_flag == 0)   # check that read is not running
                self.cmd_size = dat
                # start command read
                self.readbuf_done.clear()
                self.readbuf_start.set()
                self.readbuf_thread_flag = 1
            elif reg_addr == GPU_REG_CMDBASE_OFF:
                self.cmd_base = dat & GPU_ADDR_MASK
            elif reg_addr == GPU_REG_FBBASE_OFF:
                pass
            elif reg_addr == GPU_REG_RESET_ADDR:
                pass    # do nothing on reset
            else:
                raise ValueError("Incorrect register write via Etherbone:", hex(addr))
        elif (addr & GPU_BASE_MASK == GPU_MEMBUF_BASE):
            # GPU memory access
            self.write_mem_word((addr & GPU_ADDR_MASK), dat)
        else:
            raise ValueError("Incorrect address write via Etherbone:", hex(addr), hex(dat))
            
    def HasLighting(self):
        for s in self.pipe.config["stages"]:
            if "ILLUMINATION" in s["comment"].upper():
                return True
        return False
            
    def ReadBufThread(self):
        while not self.terminate.is_set():
            self.readbuf_start.wait()
            self.readbuf_start.clear()
            next_cmd = self.cmd_base
            for i in range(self.cmd_base, self.cmd_base+self.cmd_size*4, 4):
                if i == next_cmd:
                    cmd = self.read_mem_word(i)
                    assert(cmd & GPU_PIPE_CMD_MASK == GPU_PIPE_CMD_MASK)
                    if cmd == GPU_PIPE_CMD_SYNC:
                        self.sync_count += 1
                        
                    next_cmd += (1 + PipeCmdArgsNum(cmd))*4
                self.fifo.write(self.mem[i:i+4])
                if GENERATE_TB:
                    print(f'{self.read_mem_word(i):08X}', file = self.hex_file)
                
            if GENERATE_TB:
                self.hex_file.flush()
                print("TB cmd file write done")
                sys.exit(0)
            self.fifo.flush()
            self.readbuf_done.set()
    
