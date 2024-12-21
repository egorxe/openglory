------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Stream wrapper around afull_fifo without AXIS records.
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gpu_pkg.all;

entity stream_fifo_wrapper is
	generic (
        DEPTH   : integer := 5;    -- Number of elements in FIFO log2
        LAST    : integer := 1     -- 1 - save tlast, 0 - ignore 
    );
	port (
		clk_i           : in std_logic;
		rst_i           : in std_logic;

		s_axis_tdata    : in  std_logic_vector(GLOBAL_AXIS_DATA_WIDTH-1 downto 0);
        s_axis_tvalid   : in  std_logic;
        s_axis_tlast    : in  std_logic;
        s_axis_tready   : out std_logic;
        
        m_axis_tdata    : out std_logic_vector(GLOBAL_AXIS_DATA_WIDTH-1 downto 0);
        m_axis_tvalid   : out std_logic;
        m_axis_tlast    : out std_logic;
        m_axis_tready   : in  std_logic

	);
end stream_fifo_wrapper;

architecture stream_fifo_wrapper_arc of stream_fifo_wrapper is	

    signal mosi : global_axis_mosi_type;

begin

    fifo : entity work.stream_fifo
    generic map (
        DEPTH   => DEPTH,
        LAST    => LAST
    )
	port map (
        clk_i       => clk_i,
        rst_i       => rst_i,

        axis_mosi_i.axis_tdata  => s_axis_tdata,
        axis_mosi_i.axis_tvalid => s_axis_tvalid,
        axis_mosi_i.axis_tlast  => s_axis_tlast,
        axis_mosi_i.axis_tkeep => (others => '1'),
        axis_mosi_i.axis_tid   => (others => '0'),
        axis_mosi_i.axis_tdest => (others => '0'),
        axis_mosi_i.axis_tuser => (others => '0'),
        
        axis_miso_o.axis_tready => s_axis_tready,

        axis_mosi_o             => mosi,
        
        axis_miso_i.axis_tready => m_axis_tready
    );

m_axis_tdata    <= mosi.axis_tdata;
m_axis_tvalid   <= mosi.axis_tvalid;
m_axis_tlast    <= mosi.axis_tlast;

end stream_fifo_wrapper_arc;
