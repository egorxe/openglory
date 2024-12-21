------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Pipelined rasterizer implementation
--
-- Stages: 
--          polygon_in -> 
--          -> PRECOMPUTATION -> INCREMENT -> EDGE -> BARICENTRIC ->
--          -> fragments_out
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.gpu_pkg.all;
    use work.rast_pipe_pkg.all;

entity rast_pipe is
    port (
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
        
        polygon_i           : in  full_polygon_type;
        next_polygon_i      : in  std_logic;
        polygon_ack_o       : out std_logic;
        
        culling_i           : in  std_logic_vector(1 downto 0);
        attr_num_i          : in  attrib_num_type;
        
        busy_o              : out std_logic;
        frag_ready_o        : out std_logic;
        fragment_o          : out fragment_full_type;
        frag_pop_i          : in  std_logic;
        
        debug_o             : out vec32
    );
end rast_pipe;

architecture behav of rast_pipe is

    type edge_to_bary_array2 is array (0 to EDGE_UNITS-1) of edge_to_bary_array;

    signal polygon_ack_inc  : std_logic;
    signal next_polygon_inc : std_logic;
    
    signal incr_to_edge     : incr_to_edge_array;
    signal edge_to_incr     : edge_to_incr_array;
    signal pipe_edge_out    : edge_to_bary_array2;

    signal precomp_busy     : std_logic;
    signal edge_busy        : std_logic_vector(EDGE_UNITS-1 downto 0);
    signal bary_busy        : std_logic_vector(TOTAL_BARY_UNITS-1 downto 0);
    signal storage_busy     : std_logic;
    
    signal precomp_ready    : std_logic;
    signal bary_to_storage  : bary_to_storage_array;
    signal fifo_afull       : std_logic_vector(EDGE_UNITS-1 downto 0);
    
    signal precomp_data     : precomp_data_out_type;
    signal precomp_data_reg : precomp_data_out_type;
    
    signal fpu_share_out    : rast_fpu_share_out_array;
    signal fpu_share_in     : rast_fpu_share_in_array;
    
    function BaryNum(e : integer; b : integer) return integer is
    begin
        return e * BARY_UNITS_PER_EDGE + b;
    end function;

begin

--debug_o(0) <= next_polygon_i;
--debug_o(1) <= next_polygon_inc;
--debug_o(2) <= polygon_done_inc;
--debug_o(3) <= polygon_ack_edge;
--debug_o(4) <= next_coord_req;
--debug_o(5) <= bary_busy(0);
--debug_o(6) <= precomp_ready;
--debug_o(7) <= edge_done;
--debug_o(8) <= stall_i;
--debug_o(9) <= frag_ready_o;
--debug_o(10) <= edge_busy;
--debug_o(31 downto 11) <= (others => '0');

-- Instantiate pipeline stages

pipe_precomp : entity work.rast_pipe_precomp
    port map (
        clk_i               => clk_i,
        rst_i               => rst_i,
            
        busy_o              => precomp_busy,
            
        precomp_stb_i       => next_polygon_i, 
        polygon_ack_o       => polygon_ack_o,
        precomp_ready_o     => precomp_ready,
        precomp_ack_i       => polygon_ack_inc,
    
        polygon_i           => polygon_i,
        culling_i           => culling_i,
        attr_num_i          => attr_num_i,
        
        precomp_data_o      => precomp_data,
        
        external_fpu_i      => fpu_share_out(0),
        external_fpu_o      => fpu_share_in(0)
    );
    
pipe_increment : entity work.rast_pipe_incr
    port map (
        clk_i           => clk_i,
        rst_i           => rst_i,
        
        next_polygon_i  => precomp_ready,
        next_polygon_o  => next_polygon_inc,
        polygon_ack_o   => polygon_ack_inc,
        
        precomp_data_i  => precomp_data,
        precomp_data_o  => precomp_data_reg,
        
        incr_to_edge_o  => incr_to_edge,
        edge_to_incr_i  => edge_to_incr
    );

EDGE_GEN: for e in 0 to EDGE_UNITS-1 generate
    pipe_edgefunc : entity work.rast_pipe_edge
        port map (
            clk_i           => clk_i,
            rst_i           => rst_i,
            
            bary_busy_i     => bary_busy((e+1)*BARY_UNITS_PER_EDGE - 1 downto e*BARY_UNITS_PER_EDGE),
            next_polygon_i  => next_polygon_inc,
            precomp_data_i  => precomp_data_reg,
            stall_i         => fifo_afull(e),
            
            incr_to_edge_i  => incr_to_edge(e),
            edge_to_incr_o  => edge_to_incr(e),
            
            busy_o          => edge_busy(e), 
            pipe_edge_o     => pipe_edge_out(e)
        );
    
    BARY_GEN: for b in 0 to BARY_UNITS_PER_EDGE-1 generate
        pipe_barycentric : entity work.rast_pipe_barycentric
            port map (
                clk_i               => clk_i,
                rst_i               => rst_i,
                    
                busy_o              => bary_busy(BaryNum(e,b)),
            
                precomp_data_i      => precomp_data_reg,
                
                bary_stb_i          => pipe_edge_out(e)(b).edge_done,
                pipe_edge_i         => pipe_edge_out(e)(b).edge,
                bary_ready_o        => bary_to_storage(e).frag_ready(b),
                fragment_o          => bary_to_storage(e).fragment_out(b),
                
                external_fpu_o      => fpu_share_out(BaryNum(e,b)),
                external_fpu_i      => fpu_share_in(BaryNum(e,b))  
            );
    end generate;
end generate;

fragment_storage : entity work.rast_pipe_storage
    port map (
        clk_i               => clk_i,
        rst_i               => rst_i,
        
        bary_to_storage_i   => bary_to_storage,
        fifo_afull_o        => fifo_afull,
        
        fragment_o          => fragment_o,
        fragment_ready_o    => frag_ready_o,
        fragment_pop_i      => frag_pop_i,
        
        busy_o              => storage_busy
    );
    
-- Connect outputs
busy_o          <= or_all(bary_busy) or or_all(edge_busy) or precomp_busy or storage_busy;

end behav;
