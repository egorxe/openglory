------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- 4x4 matrix on 4x vector multiplication
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.ALL;
    use ieee.numeric_std.all;

    use work.gpu_pkg.all;

entity M4_mul_V4 is
    generic (
        MATMUL_FMAC_CNT : integer := 1      -- could be 1, 2 or 4
    );
    port (
        clk_i           : in std_logic;
        rst_i           : in std_logic;

        matrix_i        : in  M44;
        vector_i        : in  V4;
        vector_o        : out V4;

        set_i           : in  std_logic;
        start_i         : in  std_logic;
        result_ready_o  : out std_logic;
        load_ready_o    : out std_logic
    );
end entity M4_mul_V4;

architecture rtl of M4_mul_V4 is

    type fmac_args_type is array (0 to MATMUL_FMAC_CNT-1) of vec32;
    subtype fmac_stb_type is std_logic_vector(MATMUL_FMAC_CNT-1 downto 0);
    subtype fmac_num_type is integer range 0 to MATMUL_FMAC_CNT-1;
    
    type m4_mul_state_type is (IDLE, CALC);

    type reg_type is record
        state       : m4_mul_state_type;
        
        i           : integer range 0 to NWCOORDS-1;
        j           : integer range 0 to NWCOORDS-1;
        
        matrix      : M44;
        vector      : V4;
        vector_out  : V4;
        
        ready       : std_logic;
        
        fmac_stb    : fmac_stb_type;
        fmac_a      : fmac_args_type;
        fmac_b      : fmac_args_type;
        fmac_c      : fmac_args_type;
    end record;

    constant rst_reg : reg_type :=  (
        IDLE, 
        0, 0,
        (others => (others => ZERO32)), (others => ZERO32), (others => ZERO32), 
        '0', 
        (others => '0'), (others => ZERO32), (others => ZERO32), (others => ZERO32)
    );

    signal fmac_result  : fmac_args_type;
    signal fmac_ready   : fmac_stb_type;
    
    signal rin, r : reg_type;

begin

result_ready_o  <= r.ready;
load_ready_o    <= r.ready;
vector_o        <= r.vector_out;

FMAC_GEN : for i in 0 to MATMUL_FMAC_CNT-1 generate
    fmac_inst : entity work.fmac
        port map (
            clk_i       => clk_i,
            rst_i       => rst_i, 
            
            stb_i       => r.fmac_stb(i), 
            
            a_i         => r.fmac_a(i),
            b_i         => r.fmac_b(i),
            c_i         => r.fmac_c(i),
            result_o    => fmac_result(i),
            ready_o     => fmac_ready(i)
        );    
end generate;

sync : process (clk_i)
begin
    if (rising_edge(clk_i)) then
        if (rst_i = '1') then
            r <= rst_reg;
        else
            r <= rin;
        end if;
    end if;
end process;

async : process (all)
    variable v : reg_type;
    
    procedure StartFMAC(i : fmac_num_type; a : vec32; b : vec32; c : vec32) is
    begin
        v.fmac_stb(i) := '1';
        v.fmac_a(i)  := a;
        v.fmac_b(i)  := b;
        v.fmac_c(i)  := c;
    end procedure;
begin
    v := r;
    
    v.fmac_stb := (others => '0');
    
    case r.state is
        when IDLE =>
            v.ready := '1';
            
            if set_i then
                v.matrix := matrix_i;
                v.vector := vector_i;
            end if;
            
            if start_i then
                v.ready := '0';
                v.state := CALC;
                
                for i in 0 to MATMUL_FMAC_CNT-1 loop
                    StartFMAC(i, v.matrix(i)(0), v.vector(0), ZERO32);
                end loop;
            end if;
        
        when CALC =>
            if fmac_ready(0) = '1' then
                if r.j = 3 then
                    v.j := 0;
                    
                    for i in 0 to MATMUL_FMAC_CNT-1 loop
                        v.vector_out(r.i+i) := fmac_result(i);
                    end loop;
                    
                    if r.i = NWCOORDS-MATMUL_FMAC_CNT then
                        v.i := 0;
                        v.state := IDLE;
                        v.ready := '1';
                    else
                        v.i := r.i + MATMUL_FMAC_CNT;
                        
                        for i in 0 to MATMUL_FMAC_CNT-1 loop
                            StartFMAC(i, v.matrix(v.i+i)(0), v.vector(0), ZERO32);
                        end loop;
                    end if;
                else
                    v.j := r.j + 1;
                    for i in 0 to MATMUL_FMAC_CNT-1 loop
                        StartFMAC(i, r.matrix(r.i+i)(v.j), v.vector(v.j), fmac_result(i));
                    end loop;
                end if;
            end if;
    end case;

    rin <= v;
end process;

end rtl;
