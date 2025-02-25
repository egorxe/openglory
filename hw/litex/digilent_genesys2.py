#!/usr/bin/env python3

#
# This file is part of LiteX-Boards.
#
# Copyright (c) 2019 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litex_boards.platforms import digilent_genesys2

from litex.soc.cores.clock import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *
from litex.soc.cores.led import LedChaser

from litedram.modules import MT41J256M16
from litedram.phy import s7ddrphy

from liteeth.phy.s7rgmii import LiteEthPHYRGMII
from liteeth.phy.rmii import LiteEthPHYRMII

from litex.soc.cores.video import VideoVGAPHY
from litex.soc.cores.bitbang import I2CMaster
from litex.soc.cores.gpio import GPIOIn
from litex.build.generic_platform import Subsignal, Pins, IOStandard
from openglory_wb import *

# CRG ----------------------------------------------------------------------------------------------

class _CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq, gpu_clk_freq):
        self.rst       = Signal()
        self.cd_sys    = ClockDomain()
        self.cd_sys4x  = ClockDomain()
        self.cd_idelay = ClockDomain()

        # # #

        self.pll = pll = S7MMCM(speedgrade=-2)
        self.comb += pll.reset.eq(~platform.request("cpu_reset_n") | self.rst)
        pll.register_clkin(platform.request("clk200"), 200e6)
        pll.create_clkout(self.cd_sys,    sys_clk_freq)
        pll.create_clkout(self.cd_sys4x,  4*sys_clk_freq)
        pll.create_clkout(self.cd_idelay, 200e6)
        platform.add_false_path_constraints(self.cd_sys.clk, pll.clkin) # Ignore sys_clk to pll.clkin path created by SoC's rst.

        self.idelayctrl = S7IDELAYCTRL(self.cd_idelay)
        
        self.cd_gpu = ClockDomain()
        self.cd_vga = ClockDomain()
        self.pll2 = pll2 = S7MMCM(speedgrade=-2)
        pll2.register_clkin(self.cd_idelay.clk, 200e6)
        pll2.create_clkout(self.cd_gpu, gpu_clk_freq, with_reset=False)
        # pll2.create_clkout(self.cd_eth,    125e6)
        pll2.create_clkout(self.cd_vga,     25e6)

# BaseSoC ------------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, sys_clk_freq=100e6,
        with_ethernet   = False,
        with_etherbone  = False,
        with_led_chaser = True,
        with_video_terminal     = False,
        with_video_framebuffer  = False,
        
        gpu_file_list = [],
        gpu_clk_freq=100e6,
        
        **kwargs):
        platform = digilent_genesys2.Platform()

        # CRG --------------------------------------------------------------------------------------
        self.crg = _CRG(platform, sys_clk_freq, gpu_clk_freq)

        # SoCCore ----------------------------------------------------------------------------------
        SoCCore.__init__(self, platform, sys_clk_freq, ident="LiteX SoC on Genesys2", **kwargs)

        # DDR3 SDRAM -------------------------------------------------------------------------------
        if not self.integrated_main_ram_size:
            self.ddrphy = s7ddrphy.K7DDRPHY(platform.request("ddram"),
                memtype      = "DDR3",
                nphases      = 4,
                sys_clk_freq = sys_clk_freq)
            self.add_sdram("sdram",
                phy           = self.ddrphy,
                module        = MT41J256M16(sys_clk_freq, "1:4"),
                l2_cache_size = kwargs.get("l2_size", 8192)
            )

        # Ethernet / Etherbone ---------------------------------------------------------------------
        if with_ethernet or with_etherbone:
            # Bogus RMII PHY on PMOD to align memory map to AXKU040
            _rmii_io = [
                # RMII Ethernet PMOD
                ("rmii_clocks", 0,
                    Subsignal("ref_clk", Pins("U27")),
                    IOStandard("LVCMOS33")
                ),
                ("rmii", 0,
                    Subsignal("rx_data", Pins("U28 T26")),
                    Subsignal("crs_dv", Pins("T27")),
                    Subsignal("tx_en", Pins("T22")),
                    Subsignal("tx_data", Pins("T23 T20")),
                    IOStandard("LVCMOS33")
                ),
            ]
            platform.add_extension(_rmii_io)
            self.ethphy0 = LiteEthPHYRMII(
                clock_pads = self.platform.request("rmii_clocks"),
                pads = self.platform.request("rmii"),
                refclk_cd = None
            )
            
            self.ethphy1 = LiteEthPHYRGMII(
                clock_pads = self.platform.request("eth_clocks"),
                pads       = self.platform.request("eth"))
            if with_ethernet:
                self.add_ethernet(phy=self.ethphy1, phy_cd="ethphy1_eth")
            if with_etherbone:
                self.add_etherbone(phy=self.ethphy0)

        # Leds -------------------------------------------------------------------------------------
        if with_led_chaser:
            self.leds = LedChaser(
                pads         = platform.request_all("user_led"),
                sys_clk_freq = sys_clk_freq)
                
        # Video ------------------------------------------------------------------------------------
        if with_video_terminal or with_video_framebuffer:
            _vga_io = [
                ("vga", 0,
                    Subsignal("hsync", Pins("AF20")),
                    Subsignal("vsync", Pins("AG23")),
                    Subsignal("r", Pins("AK25 AG25 AH25 AK24 AJ24")),
                    Subsignal("g", Pins("AJ22 AH22 AK21 AJ21 AK23")),
                    Subsignal("b", Pins("AH20 AG20 AF21 AK20 AG22")),
                    IOStandard("LVCMOS33")
                ),
                ("i2c", 0,
                    Subsignal("sda", Pins("AF30")),
                    Subsignal("scl", Pins("AE30")),
                    IOStandard("LVCMOS33")
                ),
            ]
            platform.add_extension(_vga_io)
            
            # I2C (just to be memory map compatible with AXKU040)
            self.i2c = I2CMaster(pads=platform.request("i2c"))
            # self.buttons = GPIOIn(pads=platform.request_all("user_sw"))

            self.videophy = VideoVGAPHY(platform.request("vga"), clock_domain="vga")
            if with_video_terminal:
                self.add_video_terminal(phy=self.videophy, timings="640x480@60Hz", clock_domain="vga")
            if with_video_framebuffer:
                self.add_video_framebuffer(phy=self.videophy, timings="640x480@60Hz", clock_domain="vga")
                
        # OpenGlory GPU ---------------------------------------------------------------------------------
        add_openglory_gpu(self, self.sdram, 0x90000000, gpu_file_list, [16, 32, 32])

# Build --------------------------------------------------------------------------------------------

def main():
    from litex.build.parser import LiteXArgumentParser
    parser = LiteXArgumentParser(platform=digilent_genesys2.Platform, description="LiteX SoC on Genesys2.")
    parser.add_target_argument("--sys-clk-freq", default=100e6, type=float, help="System clock frequency.")
    ethopts = parser.target_group.add_mutually_exclusive_group()
    ethopts.add_argument("--with-ethernet",  action="store_true", help="Enable Ethernet support.")
    ethopts.add_argument("--with-etherbone", action="store_true", help="Enable Etherbone support.")
    parser.add_argument("--with-video-terminal",  action="store_true",    help="Enable Video terminal.")
    parser.add_argument("--with-video-framebuffer",  action="store_true",    help="Enable Video framebuffer.")
    sdopts = parser.target_group.add_mutually_exclusive_group()
    sdopts.add_argument("--with-spi-sdcard", action="store_true", help="Enable SPI-mode SDCard support.")
    sdopts.add_argument("--with-sdcard",     action="store_true", help="Enable SDCard support.")
    
    parser.add_target_argument("--gpu-clk-freq", default=100e6, type=float, help="GPU clock frequency.")
    parser.add_target_argument("--gpu-file-list", nargs='+', help="List of GPU HDL sources.")
    
    args = parser.parse_args()

    soc = BaseSoC(
        sys_clk_freq   = args.sys_clk_freq,
        with_ethernet  = args.with_ethernet,
        with_etherbone = args.with_etherbone,
        with_video_terminal = args.with_video_terminal,
        with_video_framebuffer = args.with_video_framebuffer,
        
        gpu_clk_freq   = args.gpu_clk_freq,
        gpu_file_list  = args.gpu_file_list,
        
        **parser.soc_argdict
    )
    if args.with_spi_sdcard:
        soc.add_spi_sdcard()
    if args.with_sdcard:
        soc.add_sdcard()
    builder = Builder(soc, **parser.builder_argdict)
    if args.build:
        builder.build(**parser.toolchain_argdict)

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(builder.get_bitstream_filename(mode="sram"))

if __name__ == "__main__":
    main()
