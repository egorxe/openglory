--------------------------------------------------------------------------------
-- Title       : <Title Block>
-- Project     : Default Project Name
--------------------------------------------------------------------------------
-- File        : M4_mul_V4_tb.vhd
-- Author      : User Name <user.email@user.company.com>
-- Company     : User Company Name
-- Created     : Sun Nov  7 18:18:47 2021
-- Last update : Tue Aug  9 17:54:36 2022
-- Platform    : Default Part Number
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Copyright (c) 2021 User Company Name
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

library work;
use work.gpu_pkg.all;

-----------------------------------------------------------

entity M4_mul_V4_tb is
end entity M4_mul_V4_tb;

-----------------------------------------------------------

architecture behaviour of M4_mul_V4_tb is

	component M4_mul_V4 is
		port (
			rst_i          : in  std_logic;
			clk_i          : in  std_logic;
			matrix_i       : in  M44;
			vector_i       : in  V4;
			vector_o       : out V4;
			set_i          : in  std_logic;
			start_i        : in  std_logic;
			result_ready_o : out std_logic;
			load_ready_o   : out std_logic;
			ine_o          : out std_logic;
			overflow_o     : out std_logic;
			underflow_o    : out std_logic;
			div_zero_o     : out std_logic;
			inf_o          : out std_logic;
			zero_o         : out std_logic;
			qnan_o         : out std_logic;
			snan_o         : out std_logic
		);
	end component;	

	-- Testbench DUT ports
	signal rst_i          : std_logic := '1';
	signal clk_i          : std_logic := '0';
	signal matrix_i       : M44 := ((0 => ("0" & "01111111" & "00000000000000000000000"), others => (others => '0')), 
									(1 => ("0" & "10000000" & "00000000000000000000000"), others => (others => '0')),
									(2 => ("0" & "10000000" & "10000000000000000000000"), others => (others => '0')),
									(3 => ("0" & "10000001" & "00000000000000000000000"), others => (others => '0')));
	signal vector_i       : V4 := (others => (ONE32)); -- 1
	signal vector_o       : V4;
	signal set_i          : std_logic := '0';
	signal start_i        : std_logic := '0';
	signal result_ready_o : std_logic;
	signal load_ready_o   : std_logic;
	signal ine_o          : std_logic;
	signal overflow_o     : std_logic;
	signal underflow_o    : std_logic;
	signal div_zero_o     : std_logic;
	signal inf_o          : std_logic;
	signal zero_o         : std_logic;
	signal qnan_o         : std_logic;
	signal snan_o         : std_logic;	

	-- Other constants
	constant clk_i_period : time := 10 ns;

begin

	clk_i_GEN : process
	begin
		clk_i <= '1';
		wait for clk_i_period / 2;
		clk_i <= '0';
		wait for clk_i_period / 2;
	end process;

	stim_proc : process
	begin
		rst_i <= '1';
		set_i <= '0';
		start_i <= '0';
		wait for clk_i_period*5;
		rst_i <= '0';
		wait for clk_i_period;
		set_i <= '1';
		start_i <= '1';
		wait for clk_i_period;
		set_i <= '0';
		start_i <= '0';
		wait until load_ready_o = '1';
		wait for clk_i_period;
		vector_i <= (others => ("1" & "01111111" & "00000000000000000000000")); -- -1
		set_i <= '1';
		start_i <= '1';
		wait for clk_i_period;
		set_i <= '0';
		start_i <= '0';
		wait until load_ready_o = '1';
		wait for clk_i_period;
		vector_i <= (others => ("0" & "10000000" & "00000000000000000000000")); -- 2
		set_i <= '1';
		start_i <= '1';
		wait for clk_i_period;
		set_i <= '0';
		start_i <= '0';
		wait;
	end process;
	-----------------------------------------------------------
	-- Entity Under Test
	-----------------------------------------------------------

	M4_mul_V4_inst : M4_mul_V4
		port map (
			rst_i          => rst_i,
			clk_i          => clk_i,
			matrix_i       => matrix_i,
			vector_i       => vector_i,
			vector_o       => vector_o,
			set_i          => set_i,
			start_i        => start_i,
			result_ready_o => result_ready_o,
			load_ready_o   => load_ready_o,
			ine_o          => ine_o,
			overflow_o     => overflow_o,
			underflow_o    => underflow_o,
			div_zero_o     => div_zero_o,
			inf_o          => inf_o,
			zero_o         => zero_o,
			qnan_o         => qnan_o,
			snan_o         => snan_o
		);	

end architecture behaviour;