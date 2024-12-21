#!/usr/bin/env python3

import argparse
import json
import sys
import os
import shutil
import resource
import traceback
import signal
from subprocess import call
from pathlib import Path

TOP_DIR     = str(Path("..").resolve()) + "/"
RTL_DIR     = TOP_DIR + "hw/gpu_rtl/"
LITEX_DIR   = TOP_DIR + "hw/litex/"
EMUSRC_DIR  = TOP_DIR + "sw/emu/"
SIM_DIR     = "sim/"
EMU_DIR     = "emu/"
SYNTH_DIR   = "synth/"
EMUHDL_DIR  = EMU_DIR + "cocotb/"
CONFIG_DIR  = "configs/"

########################################################################
################################ UTILS ################################# 
########################################################################

# Run program & return exitcode
def RunTool(call_args, wdir="", out=""):
    if not wdir:
        wdir = WORK_DIR
    if out:
        f = open(out, "w")
    else:
        f = None
    rc = call(call_args, cwd=wdir, stdout=f)
    if rc != 0:
        exit(rc)

# Exception hook        
def ExceptHook(type, value, tb):
    print("Exception hook:", value)
    traceback.print_tb(tb)
    os.killpg(0, signal.SIGKILL)

# Create dir if it does not exist
def CreateDir(path):
    Path(path).mkdir(parents=True, exist_ok=True)

########################################################################
################################ CONFIG ################################ 
########################################################################

def LoadConfig(fname):
    try:
        with open(fname) as jf:
            config = json.load(jf)
        if "files" in config:
            # parse files section with includes
            files = config["files"]
            included = True
            while included:
                included = False
                for i in range(len(files)):
                    ifiles = []
                    if files[i][0] == "#include":
                        for inc in files[i][1]:
                            print("Including", CONFIG_DIR + inc)
                            with open(CONFIG_DIR + inc) as jf:
                                iconfig = json.load(jf)
                            included = True
                            for ifile in iconfig["files"]:
                                ifiles.append(ifile)
                    if ifiles:
                        nfiles = files[:i] + ifiles
                        if i != len(files)-1:
                            nfiles += files[i+1:]
                        files = nfiles
                        break
            config["files"] = files
    except:
        print(traceback.format_exc())
        print("Failed to parse JSON config file", fname, "or its includes")
        sys.exit(1)
        
    return config

def GetFileList(config):
    result = []
    
    for dl in config["files"]:
        d = dl[0]
        for fn in dl[1]:
            result.append(RTL_DIR + d + fn)
    result = list(dict.fromkeys(result))    # remove duplicates
    return result
    
def GetFileListStr(config):
    fs = ""
    for fn in GetFileList(config):
        fs += fn + " "
    return fs

def GetGenerics(config):
    generics = ""
    if "generics" in config:
        for g in config["generics"]:
            generics += " -g"+str(g)+'='+config["generics"][g]
    return generics

########################################################################
############################## SYNTHESIS ############################### 
########################################################################

def VHDL2Verilog(config, path):
    VHD2V_MODULE = config["top"]
    VHD2V_SOURCE = VHD2V_MODULE + ".v"
    VHD2V_SCRIPT = "toverilog.ys"
    
    fs = GetFileListStr(config)
        
    generics = GetGenerics(config["synth"])
        
    with open(path + VHD2V_SCRIPT, "w") as f:
        print("ghdl -fsynopsys --std=08 --no-formal " + generics + " " + fs + "-e " + 
            VHD2V_MODULE + "\nwrite_verilog " + VHD2V_SOURCE, file=f)
        
    RunTool(["yosys", "-mghdl", VHD2V_SCRIPT], path)
    return VHD2V_SOURCE

def LitexSynth(config, use_verilog, path):
    sconfig = config["synth"]
    board = sconfig["board"]
    sys_freq = str(sconfig["sys_frequency"])
    gpu_freq = str(sconfig["gpu_frequency"])
    board_option = sconfig["litex_params"]
    file_list = ["--gpu-file-list"]
    if use_verilog:
        file_list.append(use_verilog)  
    else:
        file_list += GetFileList(config)
    RunTool(["python3", LITEX_DIR + board + ".py", "--load", "--build", "--with-video-framebuffer", 
        "--sys-clk-freq", sys_freq, "--gpu-clk-freq", gpu_freq, "--csr-csv=csr.csv", "--csr-json=csr.json"] 
        + board_option + file_list, SYNTH_DIR)
        
def Synthesis(config):
    if not ("synth" in config):
        print('No "synth" section in config!')
        sys.exit(1)
        
    CreateDir(SYNTH_DIR)
    use_verilog = None
    if ("vhdl2verilog" in config["synth"]) and (config["synth"]["vhdl2verilog"].upper() == "TRUE"):
        use_verilog = VHDL2Verilog(config, SYNTH_DIR)
    LitexSynth(config, use_verilog, SYNTH_DIR)

########################################################################
############################## SIMULATION ############################## 
########################################################################
    
def CocotbMakefile(config, path):
    fs = GetFileListStr(config)
    
    if "tbtop" in config:
        top = config["tbtop"]
    else:
        top = config["top"]
    generics = GetGenerics(config)
    if ("WAVE" in os.environ) and os.environ["WAVE"] == "1":
        wave_ghdl = "--wave=wave.ghw"
        wave_nvc = "--dump-arrays=16 --no-collapse --wave=wave.fst"
    else:
        wave_ghdl = ""
        wave_nvc = ""
    with open(path + "/Makefile", "w") as f:
        f.write(COCOTB_MAKEFILE_FMT.format(LIB="gpulib", FILES=fs, TOP=top, PYTEST=Path(TOP_DIR + config["tb"]).stem, GENERICS=generics, WAVE_GHDL=wave_ghdl, WAVE_NVC=wave_nvc))

def CreateCocotbEnv(config, path):
    CocotbMakefile(config, path)
    shutil.copy(TOP_DIR + config["tb"], path)
    if "add_files" in config:
        for afn in config["add_files"]:
            shutil.copy(TOP_DIR + afn, path)

# Launch cocotb simulation        
def Simulate(config):
    if not ("tb" in config):
        print('No "tb" in config!')
        sys.exit(1)
    
    CreateDir(SIM_DIR)    
    CreateCocotbEnv(config, SIM_DIR)
    
    # GHDL requires very large stack: ulimit -s unlimited
    resource.setrlimit(resource.RLIMIT_STACK, (resource.RLIM_INFINITY, resource.RLIM_INFINITY))    
    RunTool(["make", "-j8"], SIM_DIR)
        
COCOTB_MAKEFILE_FMT = r'''
SIM ?= ghdl

VHDL_LIB_ORDER = {LIB}
RTL_LIBRARY = {LIB}
VHDL_SOURCES_{LIB} += {FILES}

TOPLEVEL = {TOP}
MODULE = {PYTEST}

ifeq ($(SIM), nvc)
    COMPILE_ARGS = --relaxed 
    EXTRA_ARGS = -M1g -H2g 
    SIM_ARGS ?= {WAVE_NVC} --ieee-warnings=off {GENERICS} 
else
    SIM_ARGS ?= {WAVE_GHDL} --ieee-asserts=disable-at-0 {GENERICS}
    GHDL_ARGS ?= --std=08 -fsynopsys -frelaxed
endif

include $(shell python3 -m site --user-site)/cocotb/share/makefiles/Makefile.sim
'''

########################################################################
############################### EMULATION ############################## 
########################################################################

def CocotbWrapper(path, name):
    # create cocotb wrapper script for emulation stage
    with open(path + name, "w") as f:
        print('#!/bin/sh\nexport INPUT_FILE=$(readlink -f $3)\nexport OUTPUT_FILE=$(readlink -f $4)\n'\
            'cd "$(dirname "$0")"\nulimit -s unlimited\nmake', file=f)
    os.chmod(path + name, 0o755)

# Launch Python pipeline emulation        
def Emulate(config):
    if not ("emu" in config):
        print('No "emu" section in config!')
        sys.exit(1)
    
    CreateDir(EMU_DIR)
    for s in config["emu"]["stages"]:
        if "cocotb" in s:
            # create cocotb simulation environment for stage
            name = str(Path(s["cocotb"]).stem)
            path = EMUHDL_DIR + name + "/"
            CreateDir(path)
            hdl_config = LoadConfig(CONFIG_DIR + s["cocotb"])
            CreateCocotbEnv(hdl_config, path)
            CocotbWrapper(path, name)
    
    RunTool(["python3", EMUSRC_DIR + "gpu_emu.py", Path(args.config).resolve()], EMU_DIR)

########################################################################
################################# MAIN #################################
######################################################################## 

parser = argparse.ArgumentParser(description = "Script to run simulation & synthesis of OpenGLory GPU")
parser.add_argument("--config", default = "configs/default.json")
parser.add_argument("action")
args = parser.parse_args()

# ensure all children are killed on exit or exception 
os.setpgrp()                        # create process group
sys.excepthook = ExceptHook         # create  

if args.action == "prepare":
    RunTool("make", EMUSRC_DIR)
    sys.exit(0)

config = LoadConfig(args.config)

if args.action == "sim":
    Simulate(config)
elif args.action == "synth":
    Synthesis(config)
elif args.action == "emu":
    Emulate(config)
else:
    print("Action should be either prepare, sim, synth or emu")
    sys.exit(1)
    
