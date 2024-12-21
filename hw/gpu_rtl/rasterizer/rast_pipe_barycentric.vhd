------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Rasterization stages performing barycentric coord calculations.
-- Uses two FPU MAC units and one reciprocal unit (shared with precomp).
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.std_logic_unsigned.all;

library work;
    use work.gpu_pkg.all;
    use work.fp_wire.all;
    use work.rast_pipe_pkg.all;
    use work.fpupack.all;

entity rast_pipe_barycentric is
    port (
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
            
        busy_o              : out std_logic;
        --stall_i             : in  std_logic;
    
        precomp_data_i      : in  precomp_data_out_type;
        precomp_polygon_o   : out full_polygon_type; 
        
        bary_stb_i          : in  std_logic;
        pipe_edge_i         : in  pipe_edge_out_type;
        bary_ready_o        : out std_logic;
        fragment_o          : out fragment_full_type;
        
        external_fpu_o      : out rast_fpu_share_out_type;
        external_fpu_i      : in  rast_fpu_share_in_type
    );
end rast_pipe_barycentric;

architecture behav of rast_pipe_barycentric is

    constant BARYCENTRIC_FMAC_CNT    : integer := 2;
    type fmac_args_type is array (0 to BARYCENTRIC_FMAC_CNT-1) of vec32;
    subtype fmac_stb_type is std_logic_vector(BARYCENTRIC_FMAC_CNT-1 downto 0);
    subtype fmac_num_type is integer range 0 to BARYCENTRIC_FMAC_CNT-1;
    
    type bary_state_type is (
        IDLE, 
        WAIT_Z, CALC_WN, ATTRIB_ADDMUL, ATTRIB_NORM,
        SEND_RESULT --, WAIT_STALL
    );
    
    type z_state_type is (
        Z_IDLE, Z_MAC0, Z_MAC1, Z_MAC2
    );
    
    type reg_type is record
        bary_state      : bary_state_type;
        z_state         : z_state_type;
        
        fmac_stb        : fmac_stb_type;
        fmac_a          : fmac_args_type;
        fmac_b          : fmac_args_type;
        fmac_c          : fmac_args_type;
        
        reciprocal_stb  : std_logic;
        reciprocal_data : vec32;
        bary_recip_busy : std_logic;
        ext_recip_busy  : std_logic;
        
        bary_polygon    : full_polygon_type;
        pipe_edge       : pipe_edge_out_type;
        area_recip      : vec32;
        attr_num        : attrib_num_type;
        
        wn              : vec32;
        z               : vec32;
        fragment_attr   : vertex_attr_type;
        
        busy            : std_logic;
        fragment_ready  : std_logic;
        
        vertex_cnt      : vertex_num_type;
        attr_cnt        : attrib_num_type;
        
        fragment_out    : fragment_full_type;
    end record;
    
    constant r_rst  : reg_type := (
        IDLE, Z_IDLE,
        (others => '0'), (others => ZERO32), (others => ZERO32), (others => ZERO32), 
        '0', ZERO32, '0', '0',
        ZERO_FULL_POLYGON, ZERO_EFOT, ZERO32, 0,
        ZERO32, ZERO32, ZERO_VERTEX_ATTR,
        '0', '0',
        0, 0,
        ZERO_FFRAGMENT
    );
    signal r, rin   : reg_type;

    signal fmac_result          : fmac_args_type;
    signal fmac_ready           : fmac_stb_type;
    signal reciprocal_result    : vec32;
    signal reciprocal_ready     : std_logic;
    
begin

    -- Output connections
    busy_o              <= rin.busy;
    fragment_o          <= r.fragment_out;
    bary_ready_o        <= r.fragment_ready;
    
    external_fpu_o.reciprocal_busy      <= r.bary_recip_busy;
    external_fpu_o.reciprocal_ready     <= reciprocal_ready and r.ext_recip_busy;
    external_fpu_o.reciprocal_result    <= reciprocal_result;

    -- FPU units instantiation
    FMAC_GEN : for i in 0 to BARYCENTRIC_FMAC_CNT-1 generate
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

    reciprocal_inst: entity work.reciprocal
        port map (
            clk_i       => clk_i,
            rst_i       => rst_i,
            stb_i       => r.reciprocal_stb,
            data_i      => r.reciprocal_data,
            result_o    => reciprocal_result,
            ready_o     => reciprocal_ready
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
        variable v      : reg_type;
        variable rgba   : vec32;
        
        procedure StartFMAC(i : fmac_num_type; a : vec32; b : vec32; c : vec32) is
        begin
            v.fmac_stb(i) := '1';
            v.fmac_a(i)  := a;
            v.fmac_b(i)  := b;
            v.fmac_c(i)  := c;
        end procedure;
        
        procedure StartReciprocal(a : vec32) is
        begin
            v.reciprocal_stb    := '1';
            v.reciprocal_data   := a;
        end procedure;

    begin
        v := r;
        
        v.fmac_stb          := (others => '0');
        v.reciprocal_stb    := '0';
        v.fragment_ready    := '0';
        
        -- manage external FPU requests
        if reciprocal_ready then
            v.ext_recip_busy := '0';
        end if;
        
        if (r.bary_recip_busy = '0') and (external_fpu_i.reciprocal_stb = '1') then
            StartReciprocal(external_fpu_i.reciprocal_data);
            v.ext_recip_busy := '1';
        end if;
        
        -- FSM to calc attributes & Z coord for each point 
        case v.bary_state is
            -- Wait for barycentric calc request
            when IDLE =>
                if bary_stb_i = '1' then
                    -- register inputs
                    v.pipe_edge := pipe_edge_i; --! actually no need to register, just pop from fifo after done !
                    if v.pipe_edge.new_polygon then
                        v.bary_polygon  := precomp_data_i.polygon;
                        v.area_recip    := precomp_data_i.area_recip;
                        v.attr_num      := precomp_data_i.attr_num;
                    end if;
                    
                    StartFMAC(0, v.bary_polygon(0).coord.z, v.pipe_edge.ef(0), ZERO32);
                    v.z_state := Z_MAC0;
                    
                    StartFMAC(1, v.bary_polygon(0).coord.w, v.pipe_edge.ef(0), ZERO32);
                    v.bary_state := CALC_WN;
                    
                    v.bary_recip_busy := '1';
                end if;
                
            -- Calculate wn = (w0*v0[3] + w1*v1[3] + w2*v2[3])
            when CALC_WN =>
                if fmac_ready(1) then
                    if r.vertex_cnt < 2 then
                        v.vertex_cnt := r.vertex_cnt + 1;
                        StartFMAC(1, r.bary_polygon(v.vertex_cnt).coord.w, r.pipe_edge.ef(v.vertex_cnt), fmac_result(1));
                    else
                        v.bary_state := WAIT_Z;
                        StartReciprocal(fmac_result(1));
                        v.vertex_cnt := 0;
                    end if;
                end if;
            
            -- Wait for Z calculation to complete (1 more FMAC)    
            when WAIT_Z =>
                if fmac_ready(0) then
                    v.z := fmac_result(0);
                    if (float_less_than_zero(v.z) or float_more_than_one(v.z)) then
                        -- skip z<0 and z>1, kind of z-clipping
                        v.bary_recip_busy := '0';
                        v.bary_state := IDLE;
                    else
                        v.bary_state := ATTRIB_ADDMUL;
                        StartFMAC(0, r.bary_polygon(0).attr(0), r.pipe_edge.ef(0), ZERO32);
                        StartFMAC(1, r.bary_polygon(0).attr(1), r.pipe_edge.ef(0), ZERO32);
                    end if;
                end if;

            -- Calculate a = (w0 * a0 + w1 * a1 + w2 * a2)
            when ATTRIB_ADDMUL =>
                if r.bary_recip_busy and reciprocal_ready then
                    -- relies on the fact that reciprocal takes less time than 4xFMAC but more then 1xFMAC
                    v.wn := reciprocal_result;
                    v.bary_recip_busy := '0';
                end if;
                
                if fmac_ready(0) then
                    if r.vertex_cnt < 2 then
                        v.vertex_cnt := r.vertex_cnt + 1;
                        StartFMAC(0, r.bary_polygon(v.vertex_cnt).attr(r.attr_cnt), r.pipe_edge.ef(v.vertex_cnt), fmac_result(0));
                        StartFMAC(1, r.bary_polygon(v.vertex_cnt).attr(r.attr_cnt+1), r.pipe_edge.ef(v.vertex_cnt), fmac_result(1));
                    else
                        v.vertex_cnt := 0;
                        v.fragment_attr(r.attr_cnt) := fmac_result(0); 
                        v.fragment_attr(r.attr_cnt+1) := fmac_result(1);
                        if r.attr_cnt /= r.attr_num-1 then
                            -- synthesis translate_off
                            -- attribute count should be always even
                            assert(((r.attr_num-1) rem 2) = 0) severity failure;
                            -- synthesis translate_on
                            v.attr_cnt := r.attr_cnt + 2;
                            StartFMAC(0, r.bary_polygon(0).attr(v.attr_cnt), r.pipe_edge.ef(0), ZERO32);
                            StartFMAC(1, r.bary_polygon(0).attr(v.attr_cnt+1), r.pipe_edge.ef(0), ZERO32);
                        else
                            StartFMAC(0, v.fragment_attr(0), r.wn, ZERO32);
                            StartFMAC(1, v.fragment_attr(1), r.wn, ZERO32);
                            v.attr_cnt := 0;
                            v.bary_state := ATTRIB_NORM;
                        end if;
                    end if;
                end if;
            
            -- Calculate a = (w0 * a0 + w1 * a1 + w2 * a2) * wn    
            when ATTRIB_NORM =>
                if fmac_ready(0) then
                    v.fragment_attr(r.attr_cnt) := fmac_result(0);
                    v.fragment_attr(r.attr_cnt+1) := fmac_result(1);
                    if r.attr_cnt /= r.attr_num-1 then
                        v.attr_cnt := r.attr_cnt + 2;
                        StartFMAC(0, r.fragment_attr(v.attr_cnt), r.wn, ZERO32);
                        StartFMAC(1, r.fragment_attr(v.attr_cnt+1), r.wn, ZERO32);
                    else
                        v.bary_state := SEND_RESULT;
                        v.attr_cnt := 0;
                    end if;
                end if;

            -- Output resulting rasterized fragment
            when SEND_RESULT =>
                if r.attr_num < 3 then
                    -- flatshade
                    --rgba := FloatToPow2Uint(r.bary_polygon(2).attr(3), 8) & 
                            --FloatToPow2Uint(r.bary_polygon(2).attr(0), 8) & 
                            --FloatToPow2Uint(r.bary_polygon(2).attr(1), 8) & 
                            --FloatToPow2Uint(r.bary_polygon(2).attr(2), 8);
                    -- !! add offset to attr_cnt to do it correctly !!
                    rgba := ZERO32;
                else
                    rgba := FloatToPow2Uint(r.fragment_attr(3), 8) & 
                            FloatToPow2Uint(r.fragment_attr(0), 8) & 
                            FloatToPow2Uint(r.fragment_attr(1), 8) & 
                            FloatToPow2Uint(r.fragment_attr(2), 8);
                end if;
                v.fragment_out := (
                    r.pipe_edge.p.x, 
                    r.pipe_edge.p.y, 
                    FloatToPow2Uint(r.z, ZDEPTH_WDT), 
                    rgba,
                    r.fragment_attr(0),  -- !! texcoords are always attribs 0&1 for now !!
                    r.fragment_attr(1)
                );
                v.fragment_ready := '1';
                v.bary_state := IDLE;

        end case;
        
        -- Calculate Z coord
        case r.z_state is
            when Z_IDLE =>
                -- just wait for other FSM to launch calc
                null;
         
            when Z_MAC0 =>
                if fmac_ready(0) then
                    v.z_state := Z_MAC1;
                    StartFMAC(0, r.bary_polygon(1).coord.z, r.pipe_edge.ef(1), fmac_result(0));
                end if;
                
            when Z_MAC1 =>
                if fmac_ready(0) then
                    v.z_state := Z_MAC2;
                    StartFMAC(0, r.bary_polygon(2).coord.z, r.pipe_edge.ef(2), fmac_result(0));
                end if;
                
            when Z_MAC2 =>
                if fmac_ready(0) then
                    v.z_state := Z_IDLE;
                    StartFMAC(0, fmac_result(0), r.area_recip, ZERO32);
                end if;
        
        end case;
    
        v.busy := to_sl((v.bary_state /= IDLE) or (r.bary_state /= IDLE)) or r.fragment_ready;
        
        rin <= v;
    end process;

end architecture behav;
