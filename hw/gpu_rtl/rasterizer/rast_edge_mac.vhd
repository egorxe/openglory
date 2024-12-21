------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Calculate edge function using one FPU multiply-accumulate unit
--
-- E(P) = (P.x - V0.x)*(V1.y - V0.y) - (P.y - V0.y)*(V1.x - V0.x)
-- as
-- E(P)=(V0.y*V1.x-V0.x*V1.y)+P.y*(V0.x-V1.x)+P.x*(V1.y-V0.y)
--
-- Optimized for rasterization cycle with inner x coord, as it skips
-- recalculation of same values (depending on vertex & y coord only). 
--
-- Calculation time: full - 30 ticks, cached vertex - 10, cached y - 5
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gpu_pkg.all;
use work.fp_wire.all;

entity rast_edge_mac is
    port (
        clk_i       : in  std_logic;
        rst_i       : in  std_logic;

        valid_i     : in  std_logic; 
        cached_i    : in  std_logic_vector(1 downto 0); 
        ready_o     : out std_logic; 
        busy_o      : out std_logic; 

        x_i         : in  vec32;
        y_i         : in  vec32;
        v0x_i       : in  vec32;
        v0y_i       : in  vec32;
        v1x_i       : in  vec32;
        v1y_i       : in  vec32;
        result_o    : out vec32  
    );
end rast_edge_mac;

architecture behavioral of rast_edge_mac is

    constant REGISTER_FPU_IFACE : boolean := False;
    
    type edge_state_type is (IDLE, MAC0, MAC1, MAC2, MAC3, MAC4, RESULT);
    
    type reg_type is record
        fpu_arg0    : vec32;
        fpu_arg1    : vec32;
        fpu_arg2    : vec32;
        
        cached0     : vec32;
        cached1     : vec32;
        cached2     : vec32;
        cached3     : vec32;
        
        x           : vec32;
        y           : vec32;
        result      : vec32;
        
        fpu_fmadd   : std_logic;
        ready       : std_logic;
        busy        : std_logic;
        
        state       : edge_state_type;
    end record;
    
    constant r_rst  : reg_type := (
        ZERO32, ZERO32, ZERO32, 
        ZERO32, ZERO32, ZERO32, ZERO32, 
        ZERO32, ZERO32, ZERO32,
         '0', '0', '0', 
         IDLE
    );
    signal r, rin   : reg_type;

    signal fmac_result  : vec32;
    signal fmac_ready   : std_logic;
    
begin

-- Output connections
ready_o     <= r.ready;
result_o    <= r.result;
busy_o      <= r.busy;


fmac_inst : entity work.fmac
    port map (
        clk_i       => clk_i,
        rst_i       => rst_i, 
        
        stb_i       => r.fpu_fmadd, 
        
        a_i         => r.fpu_arg0,
        b_i         => r.fpu_arg1,
        c_i         => r.fpu_arg2,
        result_o    => fmac_result,
        ready_o     => fmac_ready
    );    

seq_proc : process(clk_i)
begin
    if Rising_edge(clk_i) then
        if rst_i = '1' then
            r <= r_rst;
        else
            r <= rin;
        end if;
    end if;
end process;

comb_proc : process(all)
    variable v : reg_type;
begin
    v := r;
    
    v.fpu_fmadd := '0';
    v.ready     := '0';
    v.busy      := '1';
    
    case v.state is
        when IDLE =>
            if valid_i = '1' then
                v.x := x_i;
                v.y := y_i;
                if cached_i(1) = '1' then
                    -- restart from cached inner variable state
                    v.state := RESULT;
                    v.fpu_fmadd := '1';
                    
                    v.fpu_arg0  := v.x;
                    v.fpu_arg1  := r.cached2;
                    v.fpu_arg2  := r.cached3;
                elsif cached_i(0) = '1' then
                    -- restart from cached vertex state
                    v.state := MAC4;
                    v.fpu_fmadd := '1';
                    
                    v.fpu_arg0  := v.y;
                    v.fpu_arg1  := r.cached1;
                    v.fpu_arg2  := r.cached0;
                else
                    -- start from the beginning
                    v.state := MAC0;
                    v.fpu_fmadd := '1';
                    
                    v.fpu_arg0  := v0y_i;
                    v.fpu_arg1  := v1x_i;
                    v.fpu_arg2  := ZERO32;
                end if;
            else
                v.busy := '0';
            end if;
            
        when MAC0 =>
            if fmac_ready = '1' then
                v.state := MAC1;
                v.fpu_fmadd := '1';
                
                v.fpu_arg0  := float_invert_sign(v0x_i);
                v.fpu_arg1  := v1y_i;
                v.fpu_arg2  := fmac_result;
            end if;
            
        when MAC1 =>
            if fmac_ready = '1' then
                v.state := MAC2;
                v.cached0   := fmac_result;
                v.fpu_fmadd := '1';
                
                v.fpu_arg0  := v0x_i;
                v.fpu_arg1  := ONE32;
                v.fpu_arg2  := float_invert_sign(v1x_i);
            end if;
            
        when MAC2 =>
            if fmac_ready = '1' then
                v.state := MAC3;
                v.cached1   := fmac_result;
                v.fpu_fmadd := '1';
                
                v.fpu_arg0  := v1y_i;
                v.fpu_arg1  := ONE32;
                v.fpu_arg2  := float_invert_sign(v0y_i);
            end if;
            
        when MAC3 =>
            if fmac_ready = '1' then
                v.state     := MAC4;
                v.cached2   := fmac_result;
                v.fpu_fmadd := '1';
                
                v.fpu_arg0  := r.y;
                v.fpu_arg1  := r.cached1;
                v.fpu_arg2  := r.cached0;
            end if;
            
        when MAC4 =>
            if fmac_ready = '1' then
                v.state := RESULT;
                v.cached3   := fmac_result;
                v.fpu_fmadd := '1';
                
                v.fpu_arg0  := r.x;
                v.fpu_arg1  := r.cached2;
                v.fpu_arg2  := fmac_result;
            end if;
            
        when RESULT =>
            if fmac_ready = '1' then
                v.state := IDLE;
                
                v.result    := fmac_result;
                v.ready     := '1';
                
                -- save one cycle on fmac start
                if valid_i = '1' then
                    v.x := x_i;
                    v.y := y_i;
                    if cached_i(1) = '1' then
                        -- restart from cached inner variable state
                        v.state := RESULT;
                        v.fpu_fmadd := '1';
                        
                        v.fpu_arg0  := v.x;
                        v.fpu_arg1  := r.cached2;
                        v.fpu_arg2  := r.cached3;
                    elsif cached_i(0) = '1' then
                        -- restart from cached vertex state
                        v.state := MAC4;
                        v.fpu_fmadd := '1';
                        
                        v.fpu_arg0  := v.y;
                        v.fpu_arg1  := r.cached1;
                        v.fpu_arg2  := r.cached0;
                    else
                        -- start from beginning
                        v.state := MAC0;
                        v.fpu_fmadd := '1';
                        
                        v.fpu_arg0  := v0y_i;
                        v.fpu_arg1  := v1x_i;
                        v.fpu_arg2  := ZERO32;
                    end if;
                end if;
            end if;

    end case;
    
    rin <= v;
end process;

end architecture behavioral;
