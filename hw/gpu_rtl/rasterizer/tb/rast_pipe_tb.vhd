------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Rasterizer pipeline simple testbench
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    --use ieee.numeric_std_unsigned.all;
    use ieee.float_pkg.all;

    use work.gpu_pkg.all;
    use work.rast_pipe_pkg.all;
    
    use std.env.all;

entity rast_pipe_tb is
end rast_pipe_tb;

architecture behav of rast_pipe_tb is

constant polygon    : polygon_type := (
    v => (
        (to_vec32(250.0), to_vec32(250.0), to_vec32(0.1), to_vec32(1.0), to_vec32(1.0), to_vec32(0.0), to_vec32(0.0), to_vec32(0.0)), 
        (to_vec32(250.0), to_vec32(253.5), to_vec32(0.1), to_vec32(2.0), to_vec32(0.0), to_vec32(1.0), to_vec32(0.0), to_vec32(0.0)), 
        (to_vec32(253.5), to_vec32(250.0), to_vec32(0.1), to_vec32(4.0), to_vec32(0.0), to_vec32(0.0), to_vec32(1.0), to_vec32(0.0))
    )
);
--constant backface   : std_logic := '1';
--constant polygon    : polygon_coord_type := (v => ((to_vec32(660.0), to_vec32((20.0))), 
                                            --(to_vec32((600.0)), to_vec32((10.0))), 
                                            --(to_vec32((600.0)), to_vec32((50.0)))));
--constant backface   : std_logic := '0';


signal clk              : std_logic := '0';
signal rst              : std_logic := '0';

signal polygon_done     : std_logic;
signal frag_ready       : std_logic;
signal next_polygon     : std_logic := '0';
signal next_coord       : std_logic := '0';
signal fifo_full        : std_logic := '0';

signal fragment         : fragment_type;

signal fifo_cnt         : integer := 0;

begin

uut : entity work.rast_pipe
    port map (
        clk_i           => clk,
		rst_i           => rst,
        
        polygon_i       => polygon,

        next_polygon_i  => next_polygon,
        polygon_done_o  => polygon_done,
        done_ack_i      => '0',
        
        stall_i         => fifo_full,
        frag_ready_o    => frag_ready,
        fragment_o      => fragment
    );

clk <= not clk after 5 ns;

process(clk)
    variable cnt        : integer := 0;
begin
    if Rising_edge(clk) then
        if frag_ready = '1' then
            assert fifo_full /= '1' report "FIFO overflow!" severity failure;
            fifo_cnt <= fifo_cnt + 1;
        end if;
        
        if (fifo_cnt > 0) then
            cnt := cnt + 1;
            if (cnt > 3) then
                fifo_cnt <= fifo_cnt - 1;
                cnt := 0;
            end if;
        end if;
        
        if fifo_cnt > 1023 then
            fifo_full <= '1';
        else
            fifo_full <= '0';
        end if;
    end if;
end process;

process
    variable fragments_cnt : integer := 0;
begin

    rst <= '1';
    
    wait until Rising_edge(clk);
    wait until Rising_edge(clk);
    wait until Rising_edge(clk);
    
    rst <= '0';
    
    wait until Rising_edge(clk);
    next_polygon <= '1';
    wait until Rising_edge(clk);
    next_polygon <= '0';

    while fragments_cnt < 6 loop --constant should be computed by hands for each polygon --not polygon_done = '1' loop
        if frag_ready = '1' then
            report "Fragment #" & integer'image(fragments_cnt) & " " & 
                to_string(to_uint(fragment.x)) & " " & to_string(to_uint(fragment.y)) & " " & to_string(to_uint(fragment.z)) & " " & 
                to_string(to_uint(fragment.argb(31 downto 24))) & " " & to_string(to_uint(fragment.argb(23 downto 16))) & " " & to_string(to_uint(fragment.argb(15 downto 8))) & " " & to_string(to_uint(fragment.argb(7 downto 0)));
            fragments_cnt := fragments_cnt + 1;
        end if;
        wait until Rising_edge(clk);
    end loop;

    report "SUCCESS";
    finish;

end process;

end behav;
