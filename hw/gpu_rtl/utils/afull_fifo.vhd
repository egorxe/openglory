------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Simple power of two first word fall through FIFO with almost full.
-- Could be used as AXI-Stream FIFO (with ALLOW_FULL_EMPTY = True).
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity afull_fifo is
    generic (
        DEPTH           : integer := 5;     -- Number of elements in FIFO log2
        WDT             : integer := 8;     -- Width of data in FIFO
        AFULL_OFF       : integer := 1;     -- AFULL offset
        ALLOW_FULL_EMPTY: boolean := True   -- If False - assert will be generated on pushes to full or pops from empty fifo
    );
    port (
        clk_i   : in  std_logic;  -- Input clock
        rst_i   : in  std_logic;  -- Reset line
        dat_i   : in  std_logic_vector(WDT-1 downto 0);  -- Data input
        dat_o   : out std_logic_vector(WDT-1 downto 0);  -- Data output
        push_i  : in  std_logic;  -- Push new data into FIFO
        pop_i   : in  std_logic;  -- Get data from FIFO
        full_o  : out std_logic;  -- FIFO is full
        afull_o : out std_logic;  -- FIFO is almost full
        empty_o : out std_logic   -- FIFO is empty
    );
end afull_fifo;

architecture behav of afull_fifo is
    
    type memory_type is array (0 to 2**DEPTH - 1) of std_logic_vector(WDT-1 downto 0);
    type reg_type is record
        wcnt    : std_logic_vector(DEPTH downto 0);
        rcnt    : std_logic_vector(DEPTH downto 0);
        dat_o   : std_logic_vector(WDT-1 downto 0);
        
        mem_wa  : std_logic_vector(DEPTH-1 downto 0);
        mem_we  : std_logic;
        
        full    : std_logic;
        afull   : std_logic;
        empty   : std_logic;
        
        -- synthesis translate_off
        assert_op : std_logic;
        -- synthesis translate_on
    end record;
    
    constant r_rst      : reg_type := (
        (others => '0'), 
        (others => '0'), 
        (others => '0'), 
        (others => '0'), 
        '0', 
        '0', 
        '0', 
        '1'
        -- synthesis translate_off
        ,'0'
        -- synthesis translate_on
    );
    
    signal memory       : memory_type;
    
    signal r, rin       : reg_type;

begin

full_o  <= rin.full;
afull_o <= rin.afull or rin.full;
empty_o <= r.empty;

mem_proc : process(clk_i)
begin
    if Rising_edge(clk_i) then
        dat_o <= memory(to_integer(unsigned(rin.rcnt(DEPTH-1 downto 0))));
        if (rin.mem_we = '1') then
            memory(to_integer(unsigned(r.wcnt(DEPTH-1 downto 0)))) <= dat_i;
            if rin.rcnt = r.wcnt then
                dat_o <= dat_i;
            end if;
        end if;
    end if;
end process;

seq_proc : process(clk_i)
begin
    if Rising_edge(clk_i) then
        if rst_i = '1' then
            r <= r_rst;
        else
            r <= rin;
            -- synthesis translate_off
            assert ALLOW_FULL_EMPTY or (rin.assert_op /= '0') report "Push to full or pop from empty FIFO " & afull_fifo'instance_name severity failure;
            -- synthesis translate_on
        end if;
    end if;
end process;

comb_proc : process(r, dat_i, push_i, pop_i)
    variable v : reg_type;
begin
    v := r;
    
    v.full := '0';
    v.empty := '0';
    v.mem_we := '0';
    
    v.full  := '1' when (not r.wcnt(DEPTH)) & r.wcnt(DEPTH-1 downto 0) = r.rcnt else '0';
    v.empty := '1' when (    r.wcnt(DEPTH)) & r.wcnt(DEPTH-1 downto 0) = r.rcnt else '0';
    
    -- synthesis translate_off
    v.assert_op := rst_i or ((not (v.full and push_i)) and (not (v.empty and pop_i)));
    -- synthesis translate_on
    
    if (not (v.full='1')) and (push_i='1') then
        v.mem_we := '1';
        v.mem_wa := r.wcnt(DEPTH-1 downto 0);
        v.wcnt := r.wcnt + 1;
    end if;
    
    if (not (v.empty='1')) and (pop_i='1') then
        v.rcnt := r.rcnt + 1;
    end if;
    
    -- recheck flags after changed counters
    v.full  := '1' when (not v.wcnt(DEPTH)) & v.wcnt(DEPTH-1 downto 0) = v.rcnt else '0';
    v.empty := '1' when (    v.wcnt(DEPTH)) & v.wcnt(DEPTH-1 downto 0) = v.rcnt else '0';
    --v.afull := '1' when (v.wcnt(DEPTH-1 downto 0)+1 = v.rcnt(DEPTH-1 downto 0)) else '0';
    -- ! ugly generic AFULL offset implementation !
    v.afull := '0';
    for i in 1 to AFULL_OFF loop
        if (v.wcnt(DEPTH-1 downto 0)+i = v.rcnt(DEPTH-1 downto 0)) then
            v.afull := '1';
        end if;
    end loop;
    
    rin <= v;
    
end process;

end behav;
