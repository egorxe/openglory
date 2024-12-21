library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gpu_pkg.all;

entity vertex_transform_axis_wrapper is
	generic (
		SCREEN_WIDTH  : integer := 640;
		SCREEN_HEIGHT : integer := 480
	);
	port (
		clk_i : in std_logic;
		rst_i : in std_logic;

		s_axis_tdata        : in  std_logic_vector(GLOBAL_AXIS_DATA_WIDTH - 1 downto 0);
        s_axis_tkeep        : in  std_logic_vector(3 downto 0);
        s_axis_tvalid       : in  std_logic;
        s_axis_tlast        : in  std_logic;
        s_axis_tid          : in  std_logic_vector(3 downto 0);
        s_axis_tdest        : in  std_logic_vector(3 downto 0);
        s_axis_tuser        : in  std_logic_vector(3 downto 0);
        s_axis_tready       : out std_logic;
        
        m_axis_tdata        : out std_logic_vector(GLOBAL_AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tkeep        : out std_logic_vector(3 downto 0);
        m_axis_tvalid       : out std_logic;
        m_axis_tlast        : out std_logic;
        m_axis_tid          : out std_logic_vector(3 downto 0);
        m_axis_tdest        : out std_logic_vector(3 downto 0);
        m_axis_tuser        : out std_logic_vector(3 downto 0);
        m_axis_tready       : in  std_logic

	);
end vertex_transform_axis_wrapper;

architecture vertex_transform_AXIS_wrapper_arc of vertex_transform_AXIS_wrapper is	

    constant FIFO_WDT   : integer := GLOBAL_AXIS_DATA_WIDTH + 1;
    
    signal fifo_in      : std_logic_vector(FIFO_WDT-1 downto 0);
    signal fifo_out     : std_logic_vector(FIFO_WDT-1 downto 0);
    signal fifo_push    : std_logic;
    signal fifo_full    : std_logic;
    signal fifo_empty   : std_logic;

begin

    m_axis_fifo : entity work.afull_fifo
    generic map (
        WDT     => FIFO_WDT,
        DEPTH   => 5
    )
    port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        dat_i   => fifo_in,
        dat_o   => fifo_out,
        push_i  => fifo_push,
        pop_i   => m_axis_tready,
        full_o  => fifo_full,
        empty_o => fifo_empty
    );

	--unused in slave: tkeep, tid, tdest, tuser
	m_axis_tkeep <= (others => '1');
	m_axis_tid <= (others => '0');
	m_axis_tdest <= (others => '0');
	m_axis_tuser <= (others => '0');
    
    m_axis_tvalid <= not fifo_empty;
    m_axis_tlast <= '0' when fifo_empty = '1' else fifo_out(GLOBAL_AXIS_DATA_WIDTH);
    m_axis_tdata <= fifo_out(GLOBAL_AXIS_DATA_WIDTH-1 downto 0);

	vertex_transform_unit : entity work.vertex_transform
		generic map (
			SCREEN_WIDTH  => SCREEN_WIDTH,
			SCREEN_HEIGHT => SCREEN_HEIGHT
		)
		port map (
			clk_i   => clk_i,
			rst_i   => rst_i,
			data_i  => s_axis_tdata,
			valid_i => s_axis_tvalid,
			ready_o => s_axis_tready,
            
			data_o  => fifo_in(31 downto 0),
			valid_o => fifo_push,
			last_o  => fifo_in(32),
			ready_i => not fifo_full
		);	

end vertex_transform_AXIS_wrapper_arc;
