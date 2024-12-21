#!/usr/bin/env python3

#
# This file is part of LiteX-Boards.
#
# Copyright (c) 2018-2020 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os

from migen import *
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.gen import *

# from litex_boards.platforms import alinx_axku040
import alinx_axku040_platform

from litex.soc.cores.clock import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *
from litex.soc.cores.led import LedChaser

from litedram.modules import MT40A512M16
from litedram.phy import usddrphy

from litex.soc.cores.video import VideoVGAPHY
from litex.soc.cores.bitbang import I2CMaster
from liteeth.phy.usrgmii import LiteEthPHYRGMII

from openglory_wb import *

# CRG ----------------------------------------------------------------------------------------------

class _CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq, gpu_clk_freq):
        self.rst       = Signal()
        self.cd_sys    = ClockDomain()
        self.cd_sys4x  = ClockDomain()
        self.cd_pll4x  = ClockDomain()
        self.cd_idelay = ClockDomain()
        self.cd_eth    = ClockDomain()
        self.cd_vga    = ClockDomain()
        self.cd_gpu    = ClockDomain()
        clkin_freq     = 200e6

        # # #

        self.pll = pll = USMMCM(speedgrade=-2)
        # self.comb += pll.reset.eq(platform.request("cpu_reset") | self.rst)
        self.comb += pll.reset.eq(self.rst)
        clkin = platform.request("clk200")
        pll.register_clkin(clkin, clkin_freq)
        pll.create_clkout(self.cd_pll4x, sys_clk_freq*4, buf=None, with_reset=False)
        pll.create_clkout(self.cd_idelay, 200e6)
        platform.add_false_path_constraints(self.cd_sys.clk, pll.clkin) # Ignore sys_clk to pll.clkin path created by SoC's rst.

        self.specials += [
            Instance("BUFGCE_DIV",
                p_BUFGCE_DIVIDE=4,
                i_CE=1, i_I=self.cd_pll4x.clk, o_O=self.cd_sys.clk),
            Instance("BUFGCE",
                i_CE=1, i_I=self.cd_pll4x.clk, o_O=self.cd_sys4x.clk),
        ]

        self.idelayctrl = USIDELAYCTRL(cd_ref=self.cd_idelay, cd_sys=self.cd_sys)
        
        self.pll2 = pll2 = USMMCM(speedgrade=-2)
        # pll2.register_clkin(self.cd_pll4x.clk, sys_clk_freq*4)
        # pll2.create_clkout(self.cd_gpu, gpu_clk_freq, with_reset=False)
        # pll2.create_clkout(self.cd_eth,    125e6)
        # pll2.create_clkout(self.cd_vga,     25e6)
        pll2.register_clkin(self.cd_idelay.clk, 200e6)
        pll2.create_clkout(self.cd_gpu, gpu_clk_freq, with_reset=False)
        pll2.create_clkout(self.cd_eth,    125e6)
        pll2.create_clkout(self.cd_vga,     25e6)

# BaseSoC ------------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, sys_clk_freq=125e6, 
        with_ethernet   = False,
        with_etherbone  = False,
        eth_ip          = "192.168.1.50",
        with_led_chaser = True,
        with_video_terminal     = False,
        with_video_framebuffer  = False,
        
        gpu_file_list = [],
        gpu_clk_freq=100e6,
        
        **kwargs):
        platform = alinx_axku040_platform.Platform()

        # CRG --------------------------------------------------------------------------------------
        self.crg = _CRG(platform, sys_clk_freq, gpu_clk_freq)

        # SoCCore ----------------------------------------------------------------------------------
        SoCCore.__init__(self, platform, sys_clk_freq, ident="LiteX SoC on AXKU040", **kwargs)

        # DDR4 SDRAM -------------------------------------------------------------------------------
        if not self.integrated_main_ram_size:
            self.ddrphy = usddrphy.USDDRPHY(platform.request("ddram"),
                memtype          = "DDR4",
                sys_clk_freq     = sys_clk_freq,
                iodelay_clk_freq = 200e6)
            self.add_sdram("sdram",
                phy           = self.ddrphy,
                module        = MT40A512M16(sys_clk_freq, "1:4"),
                size          = 0x40000000,
                l2_cache_min_data_width = 256,
                l2_cache_size = kwargs.get("l2_size", 8192)
            )

        # Ethernet / Etherbone ---------------------------------------------------------------------
        if with_ethernet or with_etherbone:
            self.ethphy0 = LiteEthPHYRGMII(
                clock_pads = self.platform.request("eth_clocks", 0),
                pads       = self.platform.request("eth", 0),
                tx_delay=1e-9,
                rx_delay=1e-9)
            self.ethphy1 = LiteEthPHYRGMII(
                clock_pads = self.platform.request("eth_clocks", 1),
                pads       = self.platform.request("eth", 1),
                tx_delay=1e-9,
                rx_delay=1e-9)
            if with_ethernet:
                self.add_ethernet(phy=self.ethphy1, local_ip="192.168.100.251", remote_ip="192.168.100.10", phy_cd="ethphy1_eth")
            if with_etherbone:
                self.add_etherbone(phy=self.ethphy0, ip_address=eth_ip, phy_cd="ethphy0_eth")

        # Leds -------------------------------------------------------------------------------------
        if with_led_chaser:
            self.leds = LedChaser(
                pads         = platform.request_all("user_led"),
                sys_clk_freq = sys_clk_freq)
                
        # Video ------------------------------------------------------------------------------------
        if with_video_terminal or with_video_framebuffer:
            # I2C for HDMI chip startup
            self.i2c = I2CMaster(pads=platform.request("hdmi_i2c"))
            
            self.videophy = VideoVGAPHY(platform.request("hdmi"), clock_domain="vga")
            if with_video_terminal:
                self.add_video_terminal(phy=self.videophy, timings="640x480@60Hz", clock_domain="vga")
            if with_video_framebuffer:
                self.add_video_framebuffer(phy=self.videophy, timings="640x480@60Hz", clock_domain="vga")
                
        # OpenGlory GPU ---------------------------------------------------------------------------------
        add_openglory_gpu(self, self.sdram, 0x90000000, gpu_file_list, [16, 128, 32])

# Build --------------------------------------------------------------------------------------------

def main():
    from litex.build.parser import LiteXArgumentParser
    parser = LiteXArgumentParser(platform=alinx_axku040_platform.Platform, description="LiteX SoC on AXKU040.")
    parser.add_target_argument("--sys-clk-freq", default=125e6, type=float, help="System clock frequency.")
    parser.add_argument("--with-ethernet",   action="store_true",    help="Enable Ethernet support.")
    parser.add_argument("--with-etherbone",  action="store_true",    help="Enable Etherbone support.")
    parser.add_argument("--with-video-terminal",  action="store_true",    help="Enable Video terminal.")
    parser.add_argument("--with-video-framebuffer",  action="store_true",    help="Enable Video framebuffer.")
    parser.add_target_argument("--eth-ip",    default="192.168.100.250", help="Ethernet/Etherbone IP address.")
    sdopts = parser.add_mutually_exclusive_group()
    sdopts.add_argument("--with-spi-sdcard", action="store_true", help="Enable SPI-mode SDCard support.")
    sdopts.add_argument("--with-sdcard",     action="store_true", help="Enable SDCard support.")
    
    parser.add_target_argument("--gpu-clk-freq", default=100e6, type=float, help="GPU clock frequency.")
    parser.add_target_argument("--gpu-file-list", nargs='+', help="List of GPU HDL sources.")
    args = parser.parse_args()

    json_csr = os.path.join("csr.json")
    soc = BaseSoC(
        sys_clk_freq   = args.sys_clk_freq,
        with_ethernet  = args.with_ethernet,
        with_etherbone = args.with_etherbone,
        with_video_terminal = args.with_video_terminal,
        with_video_framebuffer = args.with_video_framebuffer,
        eth_ip         = args.eth_ip,
        
        gpu_clk_freq   = args.gpu_clk_freq,
        gpu_file_list  = args.gpu_file_list,
        
        **parser.soc_argdict
	)
    
    if args.with_spi_sdcard:
        soc.add_spi_sdcard()
    if args.with_sdcard:
        soc.add_sdcard()
    builder = Builder(soc, **parser.builder_argdict)
    builder._generate_csr_map()
    if args.build:
        builder.build(**parser.toolchain_argdict)
    
    if parser.soc_argdict["cpu_type"] == "vexriscv_smp":    
        from litex.tools.litex_json2dts_linux import generate_dts
        import json
        dts = os.path.join("rv32.dts")
        with open(parser.builder_argdict["csr_json"]) as json_file, open(dts, "w") as dts_file:
            dts_content = generate_dts(json.load(json_file), polling=False)
            dts_file.write(dts_content)

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(builder.get_bitstream_filename(mode="sram"))

if __name__ == "__main__":
    main()
