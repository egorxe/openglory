------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Rasterizer pipeline constant polygon test
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.float_pkg.all;

    use work.gpu_pkg.all;
    use work.rast_pipe_pkg.all;
    
    use std.env.all;

entity rast_pipe_const is
    port (
        clk_i           : in  std_logic;
		rst_i           : in  std_logic;
        
        polygon_done_o  : out std_logic;
        next_polygon_i  : in  std_logic;
        
        fifo_full_i     : in  std_logic;
        frag_ready_o    : out std_logic;
        fragment_o      : out screen_point_type
    );
end rast_pipe_const;

architecture behav of rast_pipe_const is

constant polygon    : polygon_type := (v => ((to_vec32(238.978394), to_vec32((237.947296))), 
                                            (to_vec32((320.761963)), to_vec32((65.601410))), 
                                            (to_vec32((435.201202)), to_vec32((355.140839)))));
constant backface   : std_logic := '1';

signal clk              : std_logic := '0';
signal rst              : std_logic := '0';

begin

rasterizer : entity work.rast_pipe
    port map (
        clk_i           => clk_i,
		rst_i           => rst_i,
        
        backface_i      => backface,
        polygon_i       => polygon,
        next_polygon_i  => next_polygon_i,
        polygon_done_o  => polygon_done_o,
        
        stall_i         => fifo_full_i,
        frag_ready_o    => frag_ready_o,
        fragment_o      => fragment_o
    );

end behav;
