------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Stream wrapper around texturing without AXIS records.
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gpu_pkg.all;

entity texturing_emu_wrapper is
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
end texturing_emu_wrapper;

architecture texturing_emu_wrapper_arc of texturing_emu_wrapper is	

    signal mosi     : global_axis_mosi_type;
    signal wb_miso  : wishbone_miso_type;
    
    signal wb_ack   : std_logic;

begin

    tex : entity work.texturing_axis
    generic map (
        TEX_BASE_ADDR   => (others => '0')
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
        
        axis_miso_i.axis_tready => m_axis_tready,
        
        wb_i                    => wb_miso
    );

m_axis_tdata    <= mosi.axis_tdata;
m_axis_tvalid   <= mosi.axis_tvalid;
m_axis_tlast    <= mosi.axis_tlast;

wb_miso.wb_ack <= wb_ack;
wb_miso.wb_dati <= (others => '1');

process(clk_i)
    variable cnt : integer := 0;
    variable cnt_max : integer := 0;
    constant CNT_MAX_MAX : integer := 100;
begin
    if Rising_edge(clk_i) then
        wb_ack <= '0';
        if cnt < cnt_max then
            cnt := cnt + 1;
        else
            wb_ack <= '1';
            cnt := 0;
            if cnt_max > CNT_MAX_MAX then
                cnt_max := 0;
            else
                cnt_max := cnt_max + 3;
            end if;
        end if;
    end if;
end process;

end texturing_emu_wrapper_arc;
