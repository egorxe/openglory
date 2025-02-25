#!/usr/bin/env python3
#
# Launcher script for OpenGlory emulation, simulation & implementation
#

import argparse
import json
import sys
import os
import shutil
import re
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
    
# Stop on error
def Panic(msg, code = 1):
    print(msg)
    sys.exit(code)

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
        Panic("Failed to parse JSON config file " + fname + " or its includes")
        
    return config

def GetFileList(config, path):
    result = []
    
    if "package" in config:
        result.append(str(Path(path + "/" + config["package"]).resolve()))
        GenVhdlConfigPkg(config, path)
    
    for dl in config["files"]:
        d = dl[0]
        for fn in dl[1]:
            result.append(RTL_DIR + d + fn)
    result = list(dict.fromkeys(result))    # remove duplicates
    return result
    
def GetFileListStr(config, path):
    fs = ""
    for fn in GetFileList(config, path):
        fs += fn + " "
    return fs
 
def VhdlConst(v):
    val = str(v[1])
    if v[0] == "std_logic_vector":
        return ['"' + format(int(val, base=0), f'0{v[2]}b') + '"', val]
    elif v[0] == "std_logic":
        return ['"' + val + '"', ""]
    elif v[0] == "string":
        return ['"' + val + '"', ""]
    elif v[0] == "integer":
        return [int(val, base=0), ""]
    elif v[0] == "boolean":
        return [v[1], ""]
    else:
        Panic("Unknown VHDL type " + v[0])
        
def GenVhdlConfigPkg(config, path):
    if not "package" in config:
        return
        
    file_name = path + config["package"]
    
    if "config_vars" in config:
        constants = ""
        
        for k in config["config_vars"]:
            if not k in CONFIG_VARS:
                Panic("Unknown config variable defined: " + k)
            CONFIG_VARS[k][1] = config["config_vars"][k]
            
    for k in CONFIG_VARS:
        v = CONFIG_VARS[k]
        constants += "constant {TYPE:<20}".format(TYPE = k) + " : " + v[0]
        if v[0] == "std_logic_vector":
            constants += "(" + str(v[2]-1) + " downto 0)"
        const = VhdlConst(v)
        constants += " := {VAL}".format(VAL=const[0]) + ";"
        if const[1]:
            constants += " -- " + const[1]
        constants += "\n"
        
    pkg = VHDL_CONFIG_PKG_FMT.format(CONST = constants)
    
    open(file_name, "w").write(pkg)
    
CONFIG_VARS = {
    "BOARD_NAME"            : ["string", "Unknown "],
    "CAPABILITIES"          : ["std_logic_vector", "0", 32],
    "FAST_CLEAR"            : ["boolean", "False"],
    
    "EDGE_UNITS_POW"        : ["integer", "0"],
    "BARY_UNITS_PER_EDGE"   : ["integer", "1"],
    "TEXTURING_UNITS"       : ["integer", "1"],
    
    "SCREEN_WIDTH"          : ["integer", "640"],
    "SCREEN_HEIGHT"         : ["integer", "480"],
    
    "FB_BASE_REG"           : ["std_logic_vector", "0x3800", 32],
    "DRAM_BASE_ADDR"        : ["std_logic_vector", "0x40000000", 32],
    "FB_BASE_ADDR0"         : ["std_logic_vector", "0x40C00000", 32],
    "FB_BASE_ADDR1"         : ["std_logic_vector", "0x40D30000", 32],
    "ZBUF_BASE_ADDR"        : ["std_logic_vector", "0x40A00000", 32]
}
    
VHDL_CONFIG_PKG_FMT = r'''-- This package file is autogenerated

library ieee;
use ieee.std_logic_1164.all;

package gpu_config_pkg is

{CONST}

end package;
'''

########################################################################
############################## SYNTHESIS ############################### 
########################################################################

def VHDL2Verilog(config, path):
    if not ("vhdl2verilog" in config):
        return None
        
    VHD2V_MODULE = config["vhdl2verilog"]
    VHD2V_SOURCE = VHD2V_MODULE + ".v"
    VHD2V_SCRIPT = "toverilog.ys"
    
    # fs = GetFileListStr(config, path)
    fl = GetFileList(config, path)
    vhdl = ""
    verilog = ""
    for f in fl:
        if (f[-4:] == ".vhd") or (f[-5:] == ".vhdl"):
            vhdl += f + " "
        else:
            verilog += f + " "
            
    with open(path + VHD2V_SCRIPT, "w") as f:
        print("ghdl -fsynopsys --std=08 --no-formal " + vhdl + "-e " + 
            VHD2V_MODULE + "\nwrite_verilog " + VHD2V_SOURCE, file=f)
        
    RunTool(["yosys", "-mghdl", VHD2V_SCRIPT], path)

    return verilog + VHD2V_SOURCE

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
        file_list += GetFileList(config, SYNTH_DIR)
        
    # create "last" symlink to synth folder
    symlink = SYNTH_DIR + "build/last"
    try:
        os.remove(symlink)
    except:
        pass
    Path(symlink).symlink_to(board)
        
    RunTool(["python3", LITEX_DIR + board + ".py", "--load", "--build", "--with-video-framebuffer", 
        "--sys-clk-freq", sys_freq, "--gpu-clk-freq", gpu_freq, "--csr-csv=csr.csv", "--csr-json=csr.json"] 
        + board_option + file_list, SYNTH_DIR)
        
def Synthesis(config):
    if not ("synth" in config):
        Panic('No "synth" section in config!')
        
    CreateDir(SYNTH_DIR)
    
    LitexSynth(config, VHDL2Verilog(config, SYNTH_DIR), SYNTH_DIR)

########################################################################
############################## SIMULATION ############################## 
########################################################################
    
def CocotbMakefile(config, use_verilog, path):
    if use_verilog:
        fs = use_verilog
        lang = "verilog"
    else:
        fs = GetFileListStr(config, SIM_DIR)
        lang = "vhdl" 
    
    if "tbtop" in config:
        top = config["tbtop"]
    else:
        top = config["top"]

    with open(path + "/Makefile", "w") as f:
        f.write(COCOTB_MAKEFILE_FMT.format(LANG=lang, LIB="gpulib", FILES=fs, TOP=top, PYTEST=Path(TOP_DIR + config["tb"]).stem))

def CreateCocotbEnv(config, use_verilog, path):
    CocotbMakefile(config, use_verilog, path)
    shutil.copy(TOP_DIR + config["tb"], path)
    if "add_files" in config:
        for afn in config["add_files"]:
            shutil.copy(TOP_DIR + afn, path)

# Launch cocotb simulation        
def Simulate(config):
    if not ("tb" in config):
        Panic('No "tb" in config!')
        
    CreateDir(SIM_DIR)    
    
    use_verilog = VHDL2Verilog(config, SIM_DIR)
    
    CreateCocotbEnv(config, use_verilog, SIM_DIR)
    
    # GHDL requires very large stack: ulimit -s unlimited
    resource.setrlimit(resource.RLIMIT_STACK, (resource.RLIM_INFINITY, resource.RLIM_INFINITY))    
    RunTool(["make", "-j8"], SIM_DIR)
        
COCOTB_MAKEFILE_FMT = r'''
TOPLEVEL_LANG = {LANG}

ifeq ($(TOPLEVEL_LANG), vhdl)
    SIM ?= ghdl
    VHDL_LIB_ORDER = {LIB}
    RTL_LIBRARY = {LIB}
    VHDL_SOURCES_{LIB} += {FILES}
else
    SIM ?= icarus
    VERILOG_SOURCES += {FILES}
endif

TOPLEVEL = {TOP}
MODULE = {PYTEST}

ifeq ($(SIM), nvc)
    COMPILE_ARGS = --relaxed 
    EXTRA_ARGS =  --std=2008 -M1g -H2g 
    SIM_ARGS ?= --ieee-warnings=off
    ifeq ($(WAVE), 1)
        SIM_ARGS += --dump-arrays=16 --no-collapse --wave=wave.fst
    endif
endif

ifeq ($(SIM), ghdl)
    SIM_ARGS ?= --ieee-asserts=disable-at-0
    GHDL_ARGS ?= --std=08 -fsynopsys -frelaxed
    ifeq ($(WAVE), 1)
        SIM_ARGS += --wave=wave.ghw
    endif
endif

ifeq ($(SIM), icarus)
    ifeq ($(WAVE), 1)
        COMPILE_ARGS += -DWAVE=1
        PLUSARGS += -fst
    endif
endif

ifeq ($(SIM), verilator)
    COMPILE_ARGS = --Wno-fatal --timing -DNO_VERILOG_CLK_GEN=1
    export NO_VERILOG_CLK_GEN=1
    BUILD_ARGS += -j24 
    ifeq ($(WAVE), 1)
        COMPILE_ARGS += -DWAVE=1
        EXTRA_ARGS += --trace --trace-fst --trace-structs
    endif
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
        Panic('No "emu" section in config!')
    
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

parser = argparse.ArgumentParser(description = "Script to run simulation & synthesis of OpenGlory GPU")
parser.add_argument("--config", default = "configs/sim/default.json")
parser.add_argument("action")
args = parser.parse_args()

# ensure all children are killed on exit or exception 
os.setpgrp()                        
sys.excepthook = ExceptHook         

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
    Panic("Action should be either prepare, sim, synth or emu")
    
