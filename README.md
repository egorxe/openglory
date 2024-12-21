# OpenGlory toy GPU

OpenGlory is an implementation of fixed pipeline GPU in vendor independent VHDL and migen (LiteX) capable of running Quake. OpenGlory was verified to build and run on Xilinx Ultrascale FPGA with Vivado toolchain (Alinx AXKU040 board) and Lattice ECP5 FPGA with open GHDL+Yosys+nextpnr toolchain (Radiona ULX3S board). It could be easily ported to any FPGA board supported by LiteX and should be synthesizable for ASIC also. OpenGlory was originally started as a student project and later became a toy project intended for OpenMPW tapeout. Unfortunately OpenMPWs are in hiatus now, so ASIC builds were not tested for some time.

This repository is work in progress, most parts are not documented and may not work.

## Hardware

### Architecture

OpenGlory tries to be something like a late 90s fixed pipeline GPU with roughly OpenGL 1.x functionality. But current OpenGlory architecture has very rigid fixed pipeline implemented in VHDL without microcode and host driver reliance, which was generally not the case even for early OpenGL 1.x era GPUs. 

GPU pipeline consists of following stages:

- Vertex transformations (matrix multiplication, clipping and viewport transformation)
- Rasterization (supports several units working in parallel)
- Texturing
- Fragment operations (Z-buffer, alpha test and blending)

All pipeline stages are joined in sequence with 32-bit stream bus (subset of AXI-Stream or LiteX stream) which serves both as command and data bus. This limited bus architecture was chosen because it guarantees command ordering and simplifies verification as all stages are wholly independent of one another and could be easily replaced with software models. 

Most significant current limitations:
- Only triangle primitives are supported by rasterizer
- No lighting support
- Texturing is very simple, no texture filtering support
- Only small subset of capabilities required by Open GL ES 1.1 standard are implemented and some implemented features are not standard compliant
- Performance is rather poor which is expected and could be somewhat improved

### Interface

For video output OpenGlory uses LiteX framebuffer and video cores. DRAM memory interface provided by LiteDRAM is required for framebuffer, texture storage and etc. Currently only wishbone bus is supported for register access to GPU and memory access from it.

OpenGlory on FPGA could be used from LiteX CPU as demonstrated in NaxRiscV Quake example or from host via Etherbone, Uartbone or something similar. Only access to DRAM memory and to OpenGlory wishbone registers is required for operation.

## Directory structure

This repository has the following structure:
* **doc** - documentation and demo files
* **hw**  - hardware and verification files
    * **gpu_rtl** - OpenGlory VHDL implementation
    * **litex** - OpenGlory Litex wrapper and board files
    * **tb** - cocotb testbenches and other files
* **run** - directory for run configs and output files
    * **configs** - JSON configs for gpu.py launch script
* **sw**  - software
    * **emu** - pipeline emulator sources
    * **gles_demos** - some OpenGL ES 1 demos
    * **pseudogl** - pseudoGl library


## Software

### HDL toolchain 

For VHDL verification GHDL or NVC simulator is required. NVC is recommended as it is faster, but GHDL is also required for open source synthesis. Verification flow is based on cocotb and allows to simulate separate GPU stages or whole GPU at once and run tests on it outputting result to virtual display window.

Following tools versions were tested, although newer ones should generally work:

* GHDL v.4.1.0 (head may not work)
* NVC v.1.14.0
* Yosys v.0.42 with ghdl-yosys-plugin (only for open source synthesis)
* cocotb v.1.9.0
* LiteX (any version from year 2024 or newer should do)

Also python packages pysdl2, cocotbext-axi and cocotbext-wishbone are required for verification.

### PseudoGl

PseudoGl is a C++ library which is used for interfacing with OpenGlory toy GPU. It provides a small subset of OpenGL ES 1.1 functions which is enough for basic Quake port to work. Currently PseudoGl could interface with OpenGlory hardware in two ways - via Etherbone (also used for pipeline emulator) or directly via /dev/mem accesses (only for LiteX embedded CPU).

### OpenGL ES demos

Some simple OpenGL ES 1 demos which could be build for OpenGlory with pseudoGl or for system OpenGL implementation with SDL are located in sw/gles_demos. See readme in this folder.

### Quake port

Simple Quake port was made to run on OpenGlory with pseudoGl. See https://github.com/egorxe/glesquake .

### How to build

Directory **run** contains **gpu.py** helper script for launching emulation, HDL simulation and synthesis of OpenGlory. Here are some examples of what could be done.

To build OpenGlory with Vivado for Alinx AXKU040 board with NaxRiscV CPU:
```
./gpu.py synth --config configs/synth/alinx_axku040_nax.json
```
If build finishes successfully bitstream should appear in **synth/build/alinx_axku040_platform/gateware/alinx_axku040_platform.bit** .

To launch full pipeline simulation with NVC (will draw backbuffer by default, for visible buffer define DRAW_BACKBUFFER=0, for waveform dump also define WAVE=1):
```
SIM=nvc ./gpu.py sim
```

To launch software pipeline emulation with stages written in C++ which are much faster then HDL simulation:
```
./gpu.py prepare
./gpu.py emu --config configs/emu/default.json
```

Last two examples will create virtual display window. To render something to it you could run any of pseudoGl tests:
```
cd sw/gles_demos/simple
make -j4 oglory
../build/gles_cube.oglory
```

## Performance

Currently OpenGlory performance is quite low. Maximum Quake demo sequence performance which was achieved is ~15 FPS on average. This was achieved on Alinx AXKU040 board with NaxRiscV soft CPU running at 175 MHz. OpenGlory bus frequency was also 175 MHz and rasterizer frequency was 100 MHz. Configuration with 8-way rasterizer containing 2 barycentric calculation units per way was used (XCKU040 FPGA LUT utilization ~85%).

It is possible to fit minimal OpenGlory configuration into 83K LUT4 ECP5 FPGA (tested on Radiona ULX3S board with LFE5U-85F) but performance is obviously very low.

## Demo

Quake running at ~15 FPS on NaxRiscV:

![](https://github.com/egorxe/openglory/blob/main/doc/quake.gif)

Whole videofile is in [project wiki](https://github.com/egorxe/openglory/wiki).

## TODO

1. Fix some rasterization glitches.
2. Document usage, software and hardware architecture.
3. Implement bilinear texture filtering.
4. Improve VHDL config generation.
5. Fix and describe module tests and other testbenches.
6. Support testing converted Verilog in Verilator/Icarus.
7. Improve performance.
8. Use more fixed point arithmetic instead of floating point.
9. Implement hardware lighting.
10. Port GLES Quake 2.

## License

License for all OpenGlory code is Apache-2.0. 

The only borrowed hw code is VHDL FPU derived from https://github.com/taneroksuz/fpu-sp which is also distributed under Apache license (**hw/gpu_rtl/fpu/**).

OpenGL ES 1.1 headers distributed under Apache license are included.

Some software examples have borrowed code:
 - Old examples from NeHe Open GL lessons ported to OpenGL ES 1.1 which are distributed under MIT license (**sw/gles_demos/nehe/**).
 - OpenGL ES gears example is public domain (**sw/gles_demos/gears/**).
