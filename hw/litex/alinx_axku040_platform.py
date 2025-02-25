#
# This file is part of LiteX-Boards.
#
# Copyright (c) 2017-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from litex.build.generic_platform import *
from litex.build.xilinx import XilinxUSPlatform, VivadoProgrammer

# IOs ----------------------------------------------------------------------------------------------

_io = [
    # Clk / Rst
    ("clk125", 0,
        Subsignal("p", Pins("AF6"), IOStandard("LVDS")),
        Subsignal("n", Pins("AF5"), IOStandard("LVDS"))
    ),

    ("clk200", 0,
        Subsignal("p", Pins("AK17"), IOStandard("DIFF_SSTL12")),
        Subsignal("n", Pins("AK16"), IOStandard("DIFF_SSTL12"))
    ),

    # Leds
    ("user_led", 0, Pins("L20"), IOStandard("LVCMOS18")),
    ("user_led", 1, Pins("M20"), IOStandard("LVCMOS18")),
    ("user_led", 2, Pins("M21"), IOStandard("LVCMOS18")),
    ("user_led", 3, Pins("N21"), IOStandard("LVCMOS18")),

    # Serial
    ("serial", 0,
        Subsignal("tx",  Pins("K22")),
        Subsignal("rx",  Pins("N27")),
        IOStandard("LVCMOS18")
    ),

    # SDCard
    ("spisdcard", 0,
        Subsignal("clk",  Pins("AN8")),
        Subsignal("cs_n", Pins("AK10")),
        Subsignal("mosi", Pins("AL9"), Misc("PULLUP")),
        Subsignal("miso", Pins("AL8"), Misc("PULLUP")),
        Misc("SLEW=FAST"),
        IOStandard("LVCMOS18")
    ),
    ("sdcard", 0,
        Subsignal("clk", Pins("AN8")),
        Subsignal("cmd", Pins("AL9"), Misc("PULLUP True")),
        Subsignal("data", Pins("AL8 AP8 AJ9 AK10"), Misc("PULLUP True")),
        Misc("SLEW=FAST"),
        IOStandard("LVCMOS18")
    ),

    # HDMI
    ("hdmi", 0,
        Subsignal("r", Pins(
            "V27 W26 V26 U27 U26 U25 U24 Y22")),
        Subsignal("g", Pins(
            "V32 U34 V31 W30 W29 V29 W28 V28")),
        Subsignal("b", Pins(
            "Y30 Y33 Y32 W33 W34 W31 Y31 V34")),
        Subsignal("de",        Pins("AA33")),
        Subsignal("clk",       Pins("V33")),
        Subsignal("vsync_n",     Pins("AE31")),
        Subsignal("hsync_n",     Pins("Y28")),
        IOStandard("LVCMOS18")
    ),
    
    ("hdmi_i2c", 0,
        Subsignal("sda",   Pins("R21")),
        Subsignal("scl",   Pins("R22")),
        IOStandard("LVCMOS18"),
    ),

    # DDR4 SDRAM
    ("ddram", 0,
        Subsignal("a", Pins(
            "AG14 AF17 AF15 AJ14 AD18 AG17 AE17 AK18",
            "AD16 AH18 AD19 AD15 AH16 AL17"),
            IOStandard("SSTL12_DCI")),
        Subsignal("ba",      Pins("AG15 AL18"), IOStandard("SSTL12_DCI")),
        Subsignal("bg",      Pins("AJ15"), IOStandard("SSTL12_DCI")),
        Subsignal("ras_n",   Pins("AM19"), IOStandard("SSTL12_DCI")), # A16
        Subsignal("cas_n",   Pins("AL19"), IOStandard("SSTL12_DCI")), # A15
        Subsignal("we_n",    Pins("AL15"), IOStandard("SSTL12_DCI")), # A14
        Subsignal("cs_n",    Pins("AE18"), IOStandard("SSTL12_DCI")),
        Subsignal("act_n",   Pins("AF18"), IOStandard("SSTL12_DCI")),
        #Subsignal("ten",     Pins("AH16"), IOStandard("SSTL12_DCI")),
        #Subsignal("alert_n", Pins("AJ16"), IOStandard("SSTL12_DCI")),
        # Subsignal("par",     Pins("AF14"), IOStandard("SSTL12_DCI")),
        Subsignal("dm",      Pins("AD21 AE25 AJ21 AM21 AH26 AN26 AJ29 AL32"),
            IOStandard("POD12_DCI")),
        Subsignal("dq",      Pins(
            "AE20 AG20 AF20 AE22 AD20 AG22 AF22 AE23",
            "AF24 AJ23 AF23 AH23 AG25 AJ24 AG24 AH22",
            "AK22 AL22 AM20 AL23 AK23 AL25 AL20 AL24",
            "AM22 AP24 AN22 AN24 AN23 AP25 AP23 AM24",
            "AM26 AJ28 AM27 AK28 AH27 AH28 AK26 AK27",
            "AN28 AM30 AP28 AM29 AN27 AL30 AL29 AP29",
            "AK31 AH34 AK32 AJ31 AJ30 AH31 AJ34 AH32",
            "AN31 AL34 AN32 AN33 AM32 AM34 AP31 AP33"),
            # "AE20 AG20 AF20 AE22 AD20 AG22 AF22 AE23",
            # "AF24 AJ23 AF23 AH23 AG25 AJ24 AG24 AH22"),
            IOStandard("POD12_DCI"),
            Misc("PRE_EMPHASIS=RDRV_240"),
            Misc("EQUALIZATION=EQ_LEVEL2")),
        Subsignal("dqs_p",   Pins("AG21 AH24 AJ20 AP20 AL27 AN29 AH33 AN34"),
            IOStandard("DIFF_POD12_DCI"),
            Misc("PRE_EMPHASIS=RDRV_240"),
            Misc("EQUALIZATION=EQ_LEVEL2")),
        Subsignal("dqs_n",   Pins("AH21 AJ25 AK20 AP21 AL28 AP30 AJ33 AP34"),
            IOStandard("DIFF_POD12_DCI"),
            Misc("PRE_EMPHASIS=RDRV_240"),
            Misc("EQUALIZATION=EQ_LEVEL2")),
        Subsignal("clk_p",   Pins("AE16"), IOStandard("DIFF_SSTL12_DCI")),
        Subsignal("clk_n",   Pins("AE15"), IOStandard("DIFF_SSTL12_DCI")),
        Subsignal("cke",     Pins("AJ16"), IOStandard("SSTL12_DCI")),
        Subsignal("odt",     Pins("AG19"), IOStandard("SSTL12_DCI")),
        Subsignal("reset_n", Pins("AG16"), IOStandard("LVCMOS12")),
        Misc("SLEW=FAST"),
    ),

    # RGMII Ethernet
    ("eth_clocks", 0,
        Subsignal("tx", Pins("A10")),
        Subsignal("rx", Pins("H12")),
        IOStandard("LVCMOS18")
    ),
    ("eth", 0,
        Subsignal("rst_n",   Pins("L9")),
        Subsignal("mdio",    Pins("E12")),
        Subsignal("mdc",     Pins("F12")),
        Subsignal("rx_ctl",  Pins("C12")),
        Subsignal("rx_data", Pins("A13 B12 A12 C11")),
        Subsignal("tx_ctl",  Pins("B11")),
        Subsignal("tx_data", Pins("G12 B9 A9 B10")),
        IOStandard("LVCMOS18")
    ),
    ("eth_clocks", 1,
        Subsignal("tx", Pins("B24")),
        Subsignal("rx", Pins("D23")),
        IOStandard("LVCMOS18")
    ),
    ("eth", 1,
        Subsignal("rst_n",   Pins("H22")),
        Subsignal("mdio",    Pins("A22")),
        Subsignal("mdc",     Pins("A23")),
        Subsignal("rx_ctl",  Pins("A29")),
        Subsignal("rx_data", Pins("B29 A28 A27 C23")),
        Subsignal("tx_ctl",  Pins("A24")),
        Subsignal("tx_data", Pins("B20 A20 B21 B22")),
        IOStandard("LVCMOS18")
    ),
]

# Connectors ---------------------------------------------------------------------------------------

_connectors = []

# Platform -----------------------------------------------------------------------------------------

class Platform(XilinxUSPlatform):
    default_clk_name   = "clk200"
    default_clk_period = 1e9/200e6

    def __init__(self, toolchain="vivado"):
        XilinxUSPlatform.__init__(self, "xcku040-ffva1156-2-i", _io, _connectors, toolchain=toolchain)

    def create_programmer(self):
        return VivadoProgrammer()

    def do_finalize(self, fragment):
        XilinxUSPlatform.do_finalize(self, fragment)
        self.add_period_constraint(self.lookup_request("clk125", loose=True), 1e9/125e6)
        self.add_period_constraint(self.lookup_request("clk200", loose=True), 1e9/200e6)
        self.add_platform_command("set_property INTERNAL_VREF 0.84 [get_iobanks 44]")
        self.add_platform_command("set_property INTERNAL_VREF 0.84 [get_iobanks 45]")
        self.add_platform_command("set_property INTERNAL_VREF 0.84 [get_iobanks 46]")
