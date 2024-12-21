------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Rasterizer pipeline stage calculating pixel center coordinates  
-- (x+0.5, y+0.5) and iterating them in given range,  
-- uses simplified integer to float conversion
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.numeric_std_unsigned.all;
    use ieee.float_pkg.all;

    use work.gpu_pkg.all;
    use work.rast_pipe_pkg.all;
    
    use std.env.all;

entity rast_pipe_incr_tb is
end rast_pipe_incr_tb;

architecture behav of rast_pipe_incr_tb is
    component rast_pipe_incr is
            generic (
                SCREEN_WIDTH  : screen_coord_vec := SCREEN_640;
                SCREEN_HEIGHT : screen_coord_vec := SCREEN_480
            );
            port (
                clk_i           : in  std_logic;
                rst_i           : in  std_logic;
                
                polygon_i       : in  polygon_coord_type;
                next_polygon_i  : in  std_logic;
                next_polygon_o  : out std_logic;
                polygon_done_o  : out std_logic;
                done_ack_i      : in  std_logic;
                
                next_coord_i    : in  std_logic;
                point_o         : out point_coord_type;
                point_int_o     : out screen_point_type;
                same_line_o     : out std_logic
            );
    end component;

    signal clk_i              : std_logic := '0';
    signal rst_i              : std_logic := '0';
    signal polygon_i : polygon_coord_type := (
        v => (
            (to_vec32(250.0), to_vec32(250.0), to_vec32(0.1)), 
            (to_vec32(253.5), to_vec32(250.0), to_vec32(0.1)), 
            (to_vec32(250.0), to_vec32(253.5), to_vec32(0.1))
        )
    );
    signal next_polygon_i : std_logic := '0';
    signal next_polygon_o : std_logic;
    signal polygon_done_o : std_logic;
    signal done_ack_i : std_logic := '0';
    signal next_coord_i : std_logic := '0';
    signal point_o : point_coord_type;
    signal point_int_o : screen_point_type;
    signal same_line_o : std_logic;

begin
    uut : rast_pipe_incr
    port map (
      clk_i => clk_i,
      rst_i => rst_i,
      polygon_i => polygon_i,
      next_polygon_i => next_polygon_i,
      next_polygon_o => next_polygon_o,
      polygon_done_o => polygon_done_o,
      done_ack_i => done_ack_i,
      next_coord_i => next_coord_i,
      point_o => point_o,
      point_int_o => point_int_o,
      same_line_o => same_line_o
    );
  

    clk_i <= not clk_i after 5 ns;

    process
    begin

        rst_i <= '1';
        
        wait until Rising_edge(clk_i);
        wait until Rising_edge(clk_i);
        wait until Rising_edge(clk_i);
        
        rst_i <= '0';
        
        wait until Rising_edge(clk_i);
        next_polygon_i <= '1';
        
        wait until Rising_edge(clk_i);
        next_polygon_i <= '0';
        
        wait until Rising_edge(clk_i);
        wait until Rising_edge(clk_i);
        
        while not polygon_done_o = '1' loop
            next_coord_i <= '1';
            report real'image(to_real(point_o.x)) & " " & real'image(to_real(point_o.y));
            wait until Rising_edge(clk_i);
            next_coord_i <= '0';
            wait until Rising_edge(clk_i);
            wait until Rising_edge(clk_i);
            wait until Rising_edge(clk_i);
            wait until Rising_edge(clk_i);
        end loop;
        
        finish;

    end process;

end behav;
