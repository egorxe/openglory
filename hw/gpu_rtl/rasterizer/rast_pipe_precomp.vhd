------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Rasterization stages doing preliminary per-polygon calculations.
-- Uses single FPU MAC unit and shares a reciprocal unit with barycentric.
--
-- E(V0,V1,V2)=(V0.y*V1.x-V0.x*V1.y)+(V2.x*V1.y-V2.x*V0.y)+(V2.y*V0.x-V2.y*V1.x)
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

entity rast_pipe_precomp is
    port (
        clk_i               : in  std_logic;
        rst_i               : in  std_logic;
            
        busy_o              : out std_logic;
    
        precomp_stb_i       : in  std_logic; 
        polygon_ack_o       : out std_logic; 
        precomp_ready_o     : out std_logic; 
        precomp_ack_i       : in  std_logic;
    
        polygon_i           : in  full_polygon_type;
        culling_i           : in  std_logic_vector(1 downto 0);
        attr_num_i          : in  attrib_num_type;
        precomp_data_o      : out precomp_data_out_type;
        
        external_fpu_i      : in  rast_fpu_share_out_type;
        external_fpu_o      : out rast_fpu_share_in_type
    );
end rast_pipe_precomp;

architecture behav of rast_pipe_precomp is

    type precomp_state_type is (
        IDLE, 
        EDGE_MAC0, EDGE_MAC1, EDGE_MAC2, 
        EDGE_MAC3, EDGE_MAC4, 
        CULL_FACES, AREA_RECIP, 
        PRECALC_ATTRIB
    );
    
    type reg_type is record
        precomp_state   : precomp_state_type;
        
        fmac_stb        : std_logic;
        fmac_a          : vec32;
        fmac_b          : vec32;
        fmac_c          : vec32;
        
        reciprocal_stb  : std_logic;
        reciprocal_data : vec32;
        
        area_recip_res  : vec32;
        attr_num        : attrib_num_type;
        
        precomp_ready   : std_logic;
        busy            : std_logic;
        polygon_ack     : std_logic;
        
        vertex_cnt      : vertex_num_type;
        attr_cnt        : attrib_num_type;
        
        precomp_polygon : full_polygon_type;
    end record;
    
    constant r_rst  : reg_type := (
        IDLE,
        '0', ZERO32, ZERO32, ZERO32,
        '0', ZERO32, 
        ZERO32, 0,
        '0', '0', '0',
        0, 0,
        ZERO_FULL_POLYGON
    );
    signal r, rin   : reg_type;

    signal fmac_result          : vec32;
    signal fmac_ready           : std_logic;
    
begin

    -- Output connections
    precomp_ready_o <= r.precomp_ready;
    polygon_ack_o   <= r.polygon_ack;
    busy_o          <= rin.busy;
    
    precomp_data_o.polygon      <= r.precomp_polygon;
    precomp_data_o.area_recip   <= r.area_recip_res;
    precomp_data_o.attr_num     <= r.attr_num;
    
    external_fpu_o.reciprocal_stb   <= r.reciprocal_stb;
    external_fpu_o.reciprocal_data  <= r.reciprocal_data;

    fmac_inst : entity work.fmac
        port map (
            clk_i       => clk_i,
            rst_i       => rst_i, 
            
            stb_i       => r.fmac_stb, 
            
            a_i         => r.fmac_a,
            b_i         => r.fmac_b,
            c_i         => r.fmac_c,
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
        
        procedure StartFMAC(a : vec32; b : vec32; c : vec32) is
        begin
            v.fmac_stb  := '1';
            v.fmac_a    := a;
            v.fmac_b    := b;
            v.fmac_c    := c;
        end procedure;
        
        procedure StartReciprocal(a : vec32) is
        begin
            v.reciprocal_stb    := '1';
            v.reciprocal_data   := a;
        end procedure;

    begin
        v := r;
        
        v.fmac_stb      := '0';
        v.polygon_ack   := '0';
        
        if external_fpu_i.reciprocal_busy = '0' then
            v.reciprocal_stb    := '0';
        end if;
        
        if precomp_ack_i then
            v.precomp_ready := '0';
        end if;
              
        -- Per polygon precomputation FSM
        case v.precomp_state is
            when IDLE =>
                if (v.precomp_ready = '0') and (precomp_stb_i = '1') then
                    -- start per-polygon calculations
                    v.precomp_polygon := polygon_i;
                    v.polygon_ack := '1';
                    v.attr_num := attr_num_i;
                    StartFMAC(v.precomp_polygon(0).coord.y, v.precomp_polygon(1).coord.x, ZERO32);
                    v.precomp_state := EDGE_MAC0;
                end if;
                
            when EDGE_MAC0 =>
                if fmac_ready then
                    v.precomp_state := EDGE_MAC1;
                    StartFMAC(float_invert_sign(r.precomp_polygon(0).coord.x), r.precomp_polygon(1).coord.y, fmac_result);
                end if;
                
            when EDGE_MAC1 =>
                if fmac_ready then
                    v.precomp_state := EDGE_MAC2;
                    StartFMAC(r.precomp_polygon(2).coord.x, r.precomp_polygon(1).coord.y, fmac_result);
                end if;
                
            when EDGE_MAC2 =>
                if fmac_ready then
                    v.precomp_state := EDGE_MAC3;
                    StartFMAC(float_invert_sign(r.precomp_polygon(2).coord.x), r.precomp_polygon(0).coord.y, fmac_result);
                end if;
                
            when EDGE_MAC3 =>
                if fmac_ready then
                    v.precomp_state := EDGE_MAC4;
                    StartFMAC(r.precomp_polygon(2).coord.y, r.precomp_polygon(0).coord.x, fmac_result);
                end if;
                
            when EDGE_MAC4 =>
                if fmac_ready then
                    v.precomp_state := CULL_FACES;
                    StartFMAC(float_invert_sign(r.precomp_polygon(2).coord.y), r.precomp_polygon(1).coord.x, fmac_result);
                end if;
                
            -- Drop degenerate triangles and do face culling
            when CULL_FACES =>
                if fmac_ready then
                    if to_sl(float_exp(fmac_result) >= 127) and 
                        ((culling_i(0) and fmac_result(FLOAT_SIGN)) or 
                         (culling_i(1) and (not fmac_result(FLOAT_SIGN)))) then
                        
                        StartReciprocal(fmac_result);
                        v.precomp_state := AREA_RECIP;
                    else
                        -- skip this polygon as it either has area < 1 pixel or
                        -- faces the wrong way
                        v.precomp_state := IDLE;
                    end if;
                end if;
                
            when AREA_RECIP =>
                if external_fpu_i.reciprocal_ready then
                    v.precomp_state  := PRECALC_ATTRIB;
                    v.area_recip_res := external_fpu_i.reciprocal_result;
                    StartFMAC(r.precomp_polygon(0).attr(0), r.precomp_polygon(0).coord.w, ZERO32);
                end if;
            
            when PRECALC_ATTRIB =>
                if fmac_ready then
                    v.precomp_polygon(r.vertex_cnt).attr(r.attr_cnt) := fmac_result;
                    if r.vertex_cnt /= NVERTICES-1 then
                        v.vertex_cnt := r.vertex_cnt + 1;
                        StartFMAC(r.precomp_polygon(v.vertex_cnt).attr(r.attr_cnt), r.precomp_polygon(v.vertex_cnt).coord.w, ZERO32);
                    else
                        v.vertex_cnt := 0;
                        if r.attr_cnt /= r.attr_num then
                            v.attr_cnt := r.attr_cnt + 1;
                            StartFMAC(r.precomp_polygon(0).attr(v.attr_cnt), r.precomp_polygon(0).coord.w, ZERO32);
                        else
                            v.precomp_state := IDLE;
                            v.precomp_ready := '1';
                            v.attr_cnt := 0;
                        end if;
                    end if;
                end if;

        end case;
        
        v.busy := to_sl((v.precomp_state /= IDLE) or (r.precomp_state /= IDLE)) or r.precomp_ready;
        
        rin <= v;
    end process;

end architecture behav;
