------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Stream wrapper around afull_fifo. Saves only data & optionaly last.
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
    
use work.gpu_pkg.all;

entity stream_fifo is
    generic (
        DEPTH   : integer := 5;    -- Number of elements in FIFO log2
        LAST    : integer := 1     -- 1 - save tlast, 0 - ignore   
    );
    port (
        clk_i       : in  std_logic;  
        rst_i       : in  std_logic;  
        axis_mosi_i : in  global_axis_mosi_type;
        axis_miso_o : out global_axis_miso_type;
    
        axis_mosi_o : out global_axis_mosi_type;
        axis_miso_i : in  global_axis_miso_type
    );
end stream_fifo;

architecture behav of stream_fifo is

    constant FIFO_WDT   : integer := GLOBAL_AXIS_DATA_WIDTH + LAST;
    
    signal fifo_out     : std_logic_vector(FIFO_WDT-1 downto 0);
    signal fifo_in      : std_logic_vector(FIFO_WDT-1 downto 0);
    signal fifo_full    : std_logic;
    signal fifo_empty   : std_logic; 
    
begin

    fifo : entity work.afull_fifo
    generic map (
        WDT     => FIFO_WDT,
        DEPTH   => DEPTH
    )
    port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        dat_i   => fifo_in,
        dat_o   => fifo_out,
        push_i  => axis_mosi_i.axis_tvalid,
        pop_i   => axis_miso_i.axis_tready,
        full_o  => fifo_full,
        empty_o => fifo_empty
    );
    
LAST_GEN : if LAST > 0 generate
    fifo_in <= axis_mosi_i.axis_tlast & axis_mosi_i.axis_tdata;
else generate
    fifo_in <= axis_mosi_i.axis_tdata;
end generate;
    
    --unused in slave: tkeep, tid, tdest, tuser
	axis_mosi_o.axis_tkeep <= (others => '1');
	axis_mosi_o.axis_tid   <= (others => '0');
	axis_mosi_o.axis_tdest <= (others => '0');
	axis_mosi_o.axis_tuser <= (others => '0');
    
    axis_mosi_o.axis_tvalid <= not fifo_empty;
    
    axis_mosi_o.axis_tlast <= '0' when (LAST = 0) or (fifo_empty = '1') else fifo_out(GLOBAL_AXIS_DATA_WIDTH-1+LAST);
    axis_mosi_o.axis_tdata <= fifo_out(GLOBAL_AXIS_DATA_WIDTH-1 downto 0);
    
    axis_miso_o.axis_tready <= not fifo_full;

end behav;
