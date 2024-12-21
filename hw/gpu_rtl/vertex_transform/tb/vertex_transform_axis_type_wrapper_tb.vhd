--------------------------------------------------------------------------------
-- Title       : <Title Block>
-- Project     : Default Project Name
--------------------------------------------------------------------------------
-- File        : vertex_transform_axis_type_wrapper_tb.vhd
-- Author      : User Name <user.email@user.company.com>
-- Company     : User Company Name
-- Created     : Mon May  9 12:40:24 2022
-- Last update : Mon May  9 12:42:57 2022
-- Platform    : Default Part Number
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Copyright (c) 2022 User Company Name
-------------------------------------------------------------------------------
-- Description: 
--------------------------------------------------------------------------------
-- Revisions:  Revisions and documentation are controlled by
-- the revision control system (RCS).  The RCS should be consulted
-- on revision history.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library work;
use work.gpu_pkg.all;

-----------------------------------------------------------

entity vertex_transform_axis_type_wrapper_tb is

end entity vertex_transform_axis_type_wrapper_tb;

-----------------------------------------------------------

architecture testbench of vertex_transform_axis_type_wrapper_tb is

	-- Testbench DUT generics
	constant SCREEN_WIDTH  : integer := 640;
	constant SCREEN_HEIGHT : integer := 480;

	-- Testbench DUT ports
	signal clk_i       : std_logic;
	signal rst_i       : std_logic;
	signal axis_mosi_i : global_axis_mosi_type;
	signal axis_miso_o : global_axis_miso_type;
	signal axis_mosi_o : global_axis_mosi_type;
	signal axis_miso_i : global_axis_miso_type;

	-- Other constants
	constant C_CLK_PERIOD : real := 10.0e-9; -- NS

begin
	-----------------------------------------------------------
	-- Clocks and Reset
	-----------------------------------------------------------
	CLK_GEN : process
	begin
		clk_i <= '1';
		wait for C_CLK_PERIOD / 2.0 * (1 SEC);
		clk_i <= '0';
		wait for C_CLK_PERIOD / 2.0 * (1 SEC);
	end process CLK_GEN;

	RESET_GEN : process
	begin
		rst_i <= '1',
		         '0' after 20.0*C_CLK_PERIOD * (1 SEC);
		wait;
	end process RESET_GEN;

	-----------------------------------------------------------
	-- Testbench Stimulus
	-----------------------------------------------------------

	-----------------------------------------------------------
	-- Entity Under Test
	-----------------------------------------------------------
	DUT : entity work.vertex_transform_axis_type_wrapper
		generic map (
			SCREEN_WIDTH  => SCREEN_WIDTH,
			SCREEN_HEIGHT => SCREEN_HEIGHT
		)
		port map (
			clk_i       => clk_i,
			rst_i       => rst_i,
			axis_mosi_i => axis_mosi_i,
			axis_miso_o => axis_miso_o,
			axis_mosi_o => axis_mosi_o,
			axis_miso_i => axis_miso_i
		);

end architecture testbench;