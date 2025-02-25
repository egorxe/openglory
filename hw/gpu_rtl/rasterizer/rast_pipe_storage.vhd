------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Rasterizer pipeline final fragment buffering
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.numeric_std_unsigned.all;
    use ieee.float_pkg.all;

library work;
    use work.gpu_pkg.all;
    use work.rast_pipe_pkg.all;

entity rast_pipe_storage is
    port (
        clk_i               : in  std_logic;
		rst_i               : in  std_logic;
        
        bary_to_storage_i   : in  bary_to_storage_array;
        fifo_afull_o        : out std_logic_vector(EDGE_UNITS-1 downto 0);
            
        fragment_o          : out fragment_full_type;
        fragment_ready_o    : out std_logic;
        fragment_pop_i      : in  std_logic;
        
        busy_o              : out std_logic
    );
end rast_pipe_storage;

architecture behav of rast_pipe_storage is

constant EU : integer := EDGE_UNITS;

type fifo_data_array is array (0 to EU-1) of fragment_full_vec;

signal fifo_in      : fifo_data_array;
signal fifo_out     : fifo_data_array;
signal fifo_empty   : std_logic_vector(EU-1 downto 0);
signal fifo_afull   : std_logic_vector(EU-1 downto 0); 
signal fifo_pop     : std_logic_vector(EU-1 downto 0); 

signal fifo_sel     : integer range 0 to EU-1;

begin

busy_o <= or_all(not fifo_empty) or fragment_ready_o;

-- FIFOs for each edge unit
FIFOS_GEN : for e in 0 to EU-1 generate
    fifo : entity work.afull_fifo
        generic map (
            ALLOW_FULL_EMPTY    => False,
            DEPTH               => 6,
            AFULL_OFF           => BARY_UNITS_PER_EDGE,
            WDT                 => fragment_full_vec'length
        )
        port map (
            clk_i   => clk_i,
            rst_i   => rst_i,
            dat_i   => fifo_in(e),
            dat_o   => fifo_out(e),
            push_i  => or_all(bary_to_storage_i(e).frag_ready), 
            pop_i   => fifo_pop(e),
            afull_o => fifo_afull_o(e),
            empty_o => fifo_empty(e)
        );

    -- Put data into FIFOs
    process(all)
    begin
        --fragment_o <= fragment_out(0);
        fifo_in(e) <= Fragment2Vec(bary_to_storage_i(e).fragment_out(0));
        for b in 1 to BARY_UNITS_PER_EDGE-1 loop
            if bary_to_storage_i(e).frag_ready = work.gpu_pkg.to_slv(2**b, BARY_UNITS_PER_EDGE) then
                fifo_in(e) <= Fragment2Vec(bary_to_storage_i(e).fragment_out(b));
            end if;
        end loop;
    end process;
    
    -- synthesis translate_off
    assert count_ones(bary_to_storage_i(e).frag_ready) <= 1 
    report "Multiple barycentric outputs at the same time" & to_string(bary_to_storage_i(e).frag_ready) 
    severity failure;
    -- synthesis translate_on
end generate;

fragment_o <= Vec2Fragment(fifo_out(fifo_sel));

-- Select FIFO for output (simple synchronous selector)
process(clk_i)
    variable prio   : std_logic_vector(EDGE_UNITS_POW-1 downto 0);
    variable sel    : integer range 0 to EU-1;
    
    function FirstZeroBit(v : std_logic_vector(EU-1 downto 0); start : std_logic_vector(EDGE_UNITS_POW-1 downto 0)) return integer is
    begin
        for i in 0 to EU-1 loop
            if v(to_uint(start+i)) = '0' then
                return to_uint(start+i);
            end if;
        end loop;
        
        assert False severity failure;
        return 0;
    end function;
begin
    if Rising_edge(clk_i) then
        if rst_i then
            prio := zero_vec(EDGE_UNITS_POW);
            fifo_sel <= 0;
            fifo_pop <= zero_vec(EU);
        else
            fifo_pop <= zero_vec(EU);
            sel := 0;
            
            if or_all(not fifo_empty) = '1' then
                if EU /= 1 then
                    sel := FirstZeroBit(fifo_empty, prio);
                else
                    sel := 0;
                end if;
                if fragment_pop_i then
                    -- ! assumes that no overlapping fragments from later polygon   !
                    -- ! could be popped earlier than last from prior one           !
                    -- ! because of a static edge-unit/Y-line dependency            !
                    prio := prio + 1;   -- to pop FIFOs equally
                    fifo_pop(sel) <= '1';   
                end if;
            end if;
            
            fifo_sel <= sel;
            fragment_ready_o <= or_all(not fifo_empty);
            
            assert not ((fragment_pop_i = '1') and (fragment_ready_o /= '1')) severity failure;
            
        end if;
    end if;
end process;

end behav;
