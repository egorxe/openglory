library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gpu_pkg.all;

entity vertex_transform_axis_type_wrapper is
	generic (
			SCREEN_WIDTH  : integer := 640;
			SCREEN_HEIGHT : integer := 480
		);
	port (
			clk_i : in std_logic;
			rst_i : in std_logic;

			axis_mosi_i : in global_axis_mosi_type;
			axis_miso_o : out global_axis_miso_type;

			axis_mosi_o : out global_axis_mosi_type;
			axis_miso_i : in global_axis_miso_type
		);
end entity vertex_transform_axis_type_wrapper;

architecture behavioral of vertex_transform_axis_type_wrapper is
	component vertex_transform_axis_wrapper is
		generic (
			SCREEN_WIDTH  : integer;
			SCREEN_HEIGHT : integer
		);
		port (
			clk_i         : in  std_logic;
			rst_i         : in  std_logic;
			s_axis_tdata  : in  std_logic_vector(GLOBAL_AXIS_DATA_WIDTH - 1 downto 0);
			s_axis_tkeep  : in  std_logic_vector(3 downto 0);
			s_axis_tvalid : in  std_logic;
			s_axis_tlast  : in  std_logic;
			s_axis_tid    : in  std_logic_vector(3 downto 0);
			s_axis_tdest  : in  std_logic_vector(3 downto 0);
			s_axis_tuser  : in  std_logic_vector(3 downto 0);
			s_axis_tready : out std_logic;
			m_axis_tdata  : out std_logic_vector(GLOBAL_AXIS_DATA_WIDTH - 1 downto 0);
			m_axis_tkeep  : out std_logic_vector(3 downto 0);
			m_axis_tvalid : out std_logic;
			m_axis_tlast  : out std_logic;
			m_axis_tid    : out std_logic_vector(3 downto 0);
			m_axis_tdest  : out std_logic_vector(3 downto 0);
			m_axis_tuser  : out std_logic_vector(3 downto 0);
			m_axis_tready : in  std_logic
		);
	end component vertex_transform_axis_wrapper;	

begin

	vertex_transform_axis_wrapper_inst : vertex_transform_axis_wrapper
		generic map (
			SCREEN_WIDTH  => SCREEN_WIDTH,
			SCREEN_HEIGHT => SCREEN_HEIGHT
		)
		port map (
			clk_i         => clk_i,
			rst_i         => rst_i,

			s_axis_tdata  => axis_mosi_i.axis_tdata,
			s_axis_tkeep  => axis_mosi_i.axis_tkeep,
			s_axis_tvalid => axis_mosi_i.axis_tvalid,
			s_axis_tlast  => axis_mosi_i.axis_tlast,
			s_axis_tid    => axis_mosi_i.axis_tid,
			s_axis_tdest  => axis_mosi_i.axis_tdest,
			s_axis_tuser  => axis_mosi_i.axis_tuser,

			s_axis_tready => axis_miso_o.axis_tready,

			m_axis_tdata  => axis_mosi_o.axis_tdata,
			m_axis_tkeep  => axis_mosi_o.axis_tkeep,
			m_axis_tvalid => axis_mosi_o.axis_tvalid,
			m_axis_tlast  => axis_mosi_o.axis_tlast,
			m_axis_tid    => axis_mosi_o.axis_tid,
			m_axis_tdest  => axis_mosi_o.axis_tdest,
			m_axis_tuser  => axis_mosi_o.axis_tuser,

			m_axis_tready => axis_miso_i.axis_tready
		);	
	
end architecture behavioral;
