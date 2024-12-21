library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gpu_pkg.all;

entity rasterizer_axis_type_wrapper is
	port (
			clk_i       : in std_logic;
			rst_i       : in std_logic;

			axis_mosi_i : in global_axis_mosi_type;
			axis_miso_o : out global_axis_miso_type;

			axis_mosi_o : out global_axis_mosi_type;
			axis_miso_i : in global_axis_miso_type;
            
            debug_o     : out vec32
		);
end entity rasterizer_axis_type_wrapper;

architecture behavioral of rasterizer_axis_type_wrapper is

begin

	rasterizer_axis_wrapper : entity work.rast_pipe_axis_wrapper
		--generic map (
			--SCREEN_WIDTH  => FL32_640,
			--SCREEN_HEIGHT => FL32_480
		--)
		port map (
			clk_i           => clk_i,
			rst_i           => rst_i,
    
			s_axis_tdata    => axis_mosi_i.axis_tdata,
			s_axis_tkeep    => axis_mosi_i.axis_tkeep,
			s_axis_tvalid   => axis_mosi_i.axis_tvalid,
			s_axis_tlast    => axis_mosi_i.axis_tlast,
			s_axis_tid      => axis_mosi_i.axis_tid,
			s_axis_tdest    => axis_mosi_i.axis_tdest,
			s_axis_tuser    => axis_mosi_i.axis_tuser,
    
			s_axis_tready   => axis_miso_o.axis_tready,
    
			m_axis_tdata    => axis_mosi_o.axis_tdata,
			m_axis_tkeep    => axis_mosi_o.axis_tkeep,
			m_axis_tvalid   => axis_mosi_o.axis_tvalid,
			m_axis_tlast    => axis_mosi_o.axis_tlast,
			m_axis_tid      => axis_mosi_o.axis_tid,
			m_axis_tdest    => axis_mosi_o.axis_tdest,
			m_axis_tuser    => axis_mosi_o.axis_tuser,
    
			m_axis_tready   => axis_miso_i.axis_tready,
                
            debug_o         => debug_o
		);	
	
end architecture behavioral;
