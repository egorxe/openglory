#! /usr/bin/env python3

import sys
import os
import json
import time
import signal
import traceback
import atexit
from gpu_pipe import GpuPipeline

########### EXCEPTION HOOK ###########
def ExceptHook(type, value, tb):
    print("Exception hook:", value)
    traceback.print_tb(tb)
    os.killpg(0, signal.SIGKILL)
    # prev_except_hook(type, value, tb)
  
################ MAIN ################

if len(sys.argv) > 1:
    json_config = sys.argv[1]
else:
    print("Usage:", sys.argv[0]," json_config")

# open config file
try:
    config = json.load(open(json_config, "r"))["emu"]
except:
    print("Failed to read config file", json_config)
    sys.exit(1)

# do some dirty stuff to ensure all children are killed on exit or exception (Unix-specific!)
# os.setpgrp()                        # create process group
# prev_except_hook = sys.excepthook   # remember original exception hook
# sys.excepthook = ExceptHook         # create  

# create & run GPU pipeline
gpu_pipe = GpuPipeline(config)
gpu_pipe.Run()

