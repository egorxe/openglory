------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Wrapper around fragment without records for cocotb.
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.gpu_pkg.all;

entity fragment_tb_wrapper is
    generic (
        ADDR_WIDTH      : integer := 32;
        DATA_WIDTH      : integer := 32
    );
	port (
		--clk_i           : in std_logic;
		rst_i           : in std_logic;

		s_axis_tdata    : in  std_logic_vector(GLOBAL_AXIS_DATA_WIDTH-1 downto 0);
        s_axis_tvalid   : in  std_logic;
        s_axis_tlast    : in  std_logic;
        s_axis_tready   : out std_logic;
        
        m_axis_tdata    : out std_logic_vector(GLOBAL_AXIS_DATA_WIDTH-1 downto 0);
        m_axis_tvalid   : out std_logic;
        m_axis_tlast    : out std_logic;
        m_axis_tready   : in  std_logic;
        
        frag_wb_adr_o   : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        frag_wb_dat_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        frag_wb_sel_o   : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        frag_wb_we_o    : out std_logic;
        frag_wb_stb_o   : out std_logic;
        frag_wb_cyc_o   : out std_logic;
        frag_wb_dat_i   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        frag_wb_ack_i   : in  std_logic;
        
        fb_wb_adr_o     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        fb_wb_dat_o     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        fb_wb_sel_o     : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        fb_wb_we_o      : out std_logic;
        fb_wb_stb_o     : out std_logic;
        fb_wb_cyc_o     : out std_logic;
        fb_wb_dat_i     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        fb_wb_ack_i     : in  std_logic
	);
end fragment_tb_wrapper;

architecture texturing_tb_wrapper_arc of fragment_tb_wrapper is	

    signal clk_i        : std_logic := '0';
    signal axis_mosi    : global_axis_mosi_type;

    signal frag_wb_mosi : wishbone_mosi_type;
    signal frag_wb_miso : wishbone_miso_type;
    signal fb_wb_mosi   : wishbone_mosi_type;
    signal fb_wb_miso   : wishbone_miso_type;

begin

    clk_i <= not clk_i after 5 ns;

    frag : entity work.fragment_axis
    generic map (
        ZBUF_BASE_ADDR  => (others => '0'),
        FAST_CLEAR      => True
    )
	port map (
        clk_i       => clk_i,
        rst_i       => rst_i,

        axis_mosi_i.axis_tdata  => s_axis_tdata,
        axis_mosi_i.axis_tvalid => s_axis_tvalid,
        axis_mosi_i.axis_tlast  => '0',
        axis_mosi_i.axis_tkeep  => (others => '1'),
        axis_mosi_i.axis_tid    => (others => '0'),
        axis_mosi_i.axis_tdest  => (others => '0'),
        axis_mosi_i.axis_tuser  => (others => '0'),
        
        fb_addr_i               => X"00080000",
        
        axis_miso_o.axis_tready => s_axis_tready,

        axis_mosi_o             => axis_mosi,
        
        axis_miso_i.axis_tready => m_axis_tready,
        
        frag_wb_o               => frag_wb_mosi,
        frag_wb_i               => frag_wb_miso,
                
        fb_wb_o                 => fb_wb_mosi,
        fb_wb_i                 => fb_wb_miso
    );

-- Stream
m_axis_tdata    <= axis_mosi.axis_tdata;
m_axis_tvalid   <= axis_mosi.axis_tvalid;
m_axis_tlast    <= axis_mosi.axis_tlast;

-- Fragment WB master
frag_wb_stb_o   <= frag_wb_mosi.wb_stb;
frag_wb_cyc_o   <= frag_wb_mosi.wb_cyc;
frag_wb_adr_o   <= frag_wb_mosi.wb_adr;
frag_wb_dat_o   <= frag_wb_mosi.wb_dato;
frag_wb_we_o    <= frag_wb_mosi.wb_we;
frag_wb_sel_o   <= frag_wb_mosi.wb_sel;
frag_wb_miso    <= (wb_ack => frag_wb_ack_i, wb_dati => frag_wb_dat_i);

-- Framebuffer WB master
fb_wb_stb_o     <= fb_wb_mosi.wb_stb;
fb_wb_cyc_o     <= fb_wb_mosi.wb_cyc;
fb_wb_adr_o     <= fb_wb_mosi.wb_adr;
fb_wb_dat_o     <= fb_wb_mosi.wb_dato;
fb_wb_we_o      <= fb_wb_mosi.wb_we;
fb_wb_sel_o     <= fb_wb_mosi.wb_sel;
fb_wb_miso      <= (wb_ack => fb_wb_ack_i, wb_dati => fb_wb_dat_i);

end texturing_tb_wrapper_arc;
