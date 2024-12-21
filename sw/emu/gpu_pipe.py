import os
import numpy
from time import sleep
from threading import Thread, Event

from etherbone import RemoteServer

from gpu_display import GpuDisplay
from gpu_stage import GpuPipelineStage
from gpu_memory import GpuMemory
from gpu_defs import *

class GpuPipeline():
    def __init__(self, config):
        # Parse config
        self.config = config
        self.size_x = config["display_size_x"]
        self.size_y = config["display_size_y"]
        self.stage_num = len(config["stages"])
        
        self.pipe_ready = Event()
        self.pipe_ready.clear()
        
        # Create virtual gpu memory & regs
        if ("etherbone_regs" in config) and (config["etherbone_regs"].lower() == "true"):
            self.gpu_mem = True # small hack for FifoNames
            self.gpu_mem = GpuMemory(64*1024*1024, self.FifoNames(0)[0], self)
        else:
            self.gpu_mem = None

        # Create stages & fifos
        self.stages = [None] * self.stage_num
        for s in range(self.stage_num):
            fifos = self.FifoNames(s)
            if self.gpu_mem or s != 0:
                # no need to create first input fifo if no memory
                self.CreateFifo(fifos[0])
            self.CreateFifo(fifos[1])
            self.stages[s] = GpuPipelineStage(config, s, fifos)
            
        # Create etherbone server
        if self.gpu_mem:
            server = RemoteServer(self.gpu_mem, "127.0.0.1", 1234, 32)
            server.open()
            server.start(4)
            print("Etherbone server started")
            
        # Create display & launch thread
        self.display = GpuDisplay(self.size_x, self.size_y)
        self.frame_count = 0
        self.sync_count = 0
        self.display_finished = False
        self.global_finish = False
        self.display_thread = Thread(target = self.DisplayTickThread, daemon = False)
        self.display_thread.start()
        
        # Open last stage FIFO for framebuffer
        self.fb_fifo = open(self.FifoNames(self.stage_num-1)[1], "rb")
        
        self.pipe_ready.set()
    
    def FifoNames(self, stage):
        if (not self.gpu_mem) and stage == 0:
            fifo_in = "" #self.config["input_file"]
        else:
            fifo_in = str(stage)+".fifo"
        return (fifo_in, str(stage+1)+".fifo")
        
    def CreateFifo(self, name):
        # remove old file if exists & create new fifo file
        try:
            os.remove(name)
        except:
            pass
        os.mkfifo(name)
        
    def ReadFifo(self):
        bword = self.fb_fifo.read(4)
        cmd = int.from_bytes(bword, "little")
        # parse command
        if cmd == GPU_PIPE_CMD_FRAGMENT:
            bword = self.fb_fifo.read(12)
            return (int.from_bytes(bword[:2], "little"), int.from_bytes(bword[2:4], "little"), int.from_bytes(bword[4:8], "little"), int.from_bytes(bword[8:12], "little"))
        elif cmd == GPU_PIPE_CMD_CLEAR_FB:
            self.display.ClearFramebuffer()
        elif cmd == GPU_PIPE_CMD_SYNC:
            self.sync_count += 1
            # treat sync as a new frame if running without registers emulation
            if not self.gpu_mem:
                self.NextFrame()
        else:
            # ignore everything but fragments & syncs - read & drop all arguments
            print("Unknown command at the end of pipeline", hex(cmd))
            assert(cmd & GPU_PIPE_CMD_MASK == GPU_PIPE_CMD_MASK)
            for i in range(PipeCmdArgsNum(cmd)):
                self.fb_fifo.read(4)
            return None
        
    def NextFrame(self):
        self.display.DrawFramebuffer()
        self.frame_count += 1
        print("Frame", self.frame_count)
        
    def Tick(self):
        try:
            fragment = self.ReadFifo()
        except:
            print("Failed to read FIFO!")
            return True
        
        if fragment:
            self.display.PutFragment(fragment)

        return False
        
    def DisplayTickThread(self):
        finish = False
        while not (finish or self.global_finish):
            sleep(0.1)
            finish = self.display.Tick()
            for s in self.stages:
                # check that all stages are alive
                finish = finish or (not s.CheckAlive())
        self.display_finished = True
        
    def Run(self):
        finish = False
        while not finish:
            finish = self.Tick() or self.display_finished
            
        # cleanup
        self.global_finish = True
        for s in self.stages:
            s.Stop()
        sleep(0.2)
