------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- W clipping, perspective division and viewport transformations
--
-- Clipping is done only on W plane with the following algo:     
-- c = current vertex, p = previous vertex, n - new vertex, 
-- A - vertex coord/attr 
--                                                                                
-- All vertices are checked sequentially.                                         
-- If (Wp > W_CLIP_VAL) then p is kept, else it is dropped.                   
--                                                                                
-- If edge going from p to c intersects W plane (Wp and Wc have 
-- different signs) then new vertex is created on plane intersection.                                
--                                                                                
-- Intersection factor (f) is: f = (W_CLIP_VAL - Wp) / (Wc - Wp)                  
-- New vertex coords & attributes are: An = Ap + f(Ac-Ap)                         
--                                                                                
-- As a result we get either 3 or 4 vertices (one or two triangles) 
--
-- NOTE:
-- In OpenGL ES color clipping is specified to be done AFTER lighting
-- and color clamping, but we do it before together with coord clipping.
-- This will lead to different color results for clipped polygons with
-- lighting, especially with color values out of [-1,1] range.
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.gpu_pkg.all;
use work.gpu_vertex_pkg.all;

entity clipping_viewport is
    port (
            clk_i           : in  std_logic;
            rst_i           : in  std_logic;

            vertex_i        : in  full_vertex_type;
            vertex_ready_i  : in  std_logic;
            busy_o          : out std_logic;
            input_busy_o    : out std_logic;
            
            viewport_i      : in  viewport_params;
            attrib_num_i    : in  attrib_num_type;
            cmd_i           : in  vec32;
            
            data_o          : out vec32;
            valid_o         : out std_logic;
            last_o          : out std_logic;
            ready_i         : in  std_logic
    );
end clipping_viewport;

architecture behavioral of clipping_viewport is

    constant W_CLIP_EXP : integer := 114;
    constant W_CLIP_VAL : vec32  := "0" & to_slv(W_CLIP_EXP-1, FLOAT_EXP_WDT) & max_vec(FLOAT_MANT_WDT); -- ~0.00012
    constant NCLIPPARAM : integer := NCOORDS+NVERTEX_ATTR;
    
    type clip_polygon_type is array (0 to 3) of full_vertex_type;   -- one additional vertex for clipping
    constant ZERO_CLIP_POLYGON : clip_polygon_type := (others => ZERO_FULL_VERTEX);

    type state_type is (
        VERTEX_INPUT, CALC_W_RECIPROCAL, WAIT_PERSPECTIVE_DIVIDE, 
        VIEWPORT_0, VIEWPORT_1, VIEWPORT_2, VIEWPORT_3, WAIT_FOR_SEND, 
        CLIP_F_0, CLIP_F_1, CLIP_F_2, 
        CLIP_A_0, CLIP_A_1, CLIP_A_2, CLIP_FINISH
    );
    type send_state_type is (SEND_IDLE, SEND_WAIT_READY, SEND_COORDS_0, SEND_COORDS_1, SEND_ATTRIBS);

    type reg_type is record
        state               : state_type;
        send_state          : send_state_type;
            
        polygon             : full_polygon_type;
            
        busy                : std_logic;
        input_busy          : std_logic;
            
        reciprocal_stb      : std_logic;
        reciprocal_data     : vec32;
        fmac_stb            : std_logic;
        fmac_a              : vec32;
        fmac_b              : vec32;
        fmac_c              : vec32;
            
        need_clipping       : std_logic_vector(2 downto 0);
        w_ready             : std_logic_vector(2 downto 0);
        vertex_ready        : std_logic_vector(2 downto 0);
        persp_fmac_busy     : std_logic;
            
        vertex_cnt          : integer range 0 to 2;
        persp_vertex        : integer range 0 to 2;
        send_vertex         : integer range 0 to 2;
        clip_prev_vertex    : integer range 0 to 2;
        clip_new_vertex     : integer range 0 to 4;
        clip_vertex         : integer range 0 to 2;
            
        persp_coord         : integer range 0 to 3;
        send_cnt            : integer range 0 to NVERTEX_ATTR-1;
            
        clipped_polygon     : clip_polygon_type;
        clip_ifactor        : vec32;
        clip_add_polygon    : std_logic;
        clip_param          : integer range 0 to NCLIPPARAM-1;
        
        attrib_num          : attrib_num_type;
        cmd                 : vec32;
            
        send_data           : vec32;
        send_valid          : std_logic;
        send_last           : std_logic;
    end record;
    
    constant R_RST  : reg_type := (
        VERTEX_INPUT, SEND_IDLE,
        ZERO_FULL_POLYGON,
        '0', '0',
        '0', ZERO32, '0', ZERO32, ZERO32, ZERO32,
        "000", "000", "000", '0',
        0, 0, 0, 0, 0, 0,
        0, 0,
        ZERO_CLIP_POLYGON, ZERO32, '0', 0,
        0, ZERO32,
        ZERO32, '0', '0'
    );
    signal r, rin   : reg_type;
    
    signal reciprocal_ready     : std_logic;
    signal reciprocal_result    : vec32;
    signal fmac_ready           : std_logic;
    signal fmac_result          : vec32;


begin

-- Out connections
busy_o <= r.busy;
input_busy_o <= r.input_busy;

data_o  <= r.send_data;
valid_o <= r.send_valid;
last_o  <= r.send_last;

-- Floating math units
reciprocal_inst: entity work.reciprocal
    port map (
        clk_i       => clk_i,
        rst_i       => rst_i,
        stb_i       => r.reciprocal_stb,
        data_i      => r.reciprocal_data,
        result_o    => reciprocal_result,
        ready_o     => reciprocal_ready
    );
    
fmac_inst: entity work.fmac
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


-- Sequential processes
seq_proc : process(clk_i)
begin
    if Rising_edge(clk_i) then
        if rst_i = '1' then
            r <= R_RST;
        else
            r <= rin;
        end if;
    end if;
end process;

-- Combinational process
async_proc : process(all)
    variable v          : reg_type;
    
    procedure SetCoordInPolygon(vert : integer range 0 to 2; c : integer range 0 to 3; nv : vec32) is
    begin
        case c is
            when 0 =>
                v.polygon(vert).coord.x := nv;
            when 1 =>
                v.polygon(vert).coord.y := nv;
            when 2 =>
                v.polygon(vert).coord.z := nv;
            when 3 =>
                v.polygon(vert).coord.w := nv;
        end case;
    end procedure;
    
    procedure SetParamInClipPolygon(vert : integer range 0 to 3; p : integer range 0 to NCLIPPARAM-1; nv : vec32) is
    begin
        case p is
            when 0 =>
                v.clipped_polygon(vert).coord.x := nv;
            when 1 =>
                v.clipped_polygon(vert).coord.y := nv;
            when 2 =>
                v.clipped_polygon(vert).coord.z := nv;
            when others =>
                v.clipped_polygon(vert).attr(p-3) := nv;
        end case;
    end procedure;
    
    function CheckWClip(w : vec32) return std_logic is
    begin
        return w(FLOAT_SIGN) or to_sl(float_exp(w) < W_CLIP_EXP);
    end function;

begin
    v := r;
    
    v.reciprocal_stb := '0';
    v.fmac_stb := '0';
    
    v.input_busy := '1';
    
    case r.state is
    
        -- Wait for polygon vertexes
        when VERTEX_INPUT =>
            v.input_busy := '0';
            
            if r.vertex_cnt = 0 then
                v.busy := '0';
                v.need_clipping := "000";
            end if;
            
            if vertex_ready_i then
                v.busy  := '1';
                v.polygon(r.vertex_cnt) := vertex_i;
                
                v.need_clipping(r.vertex_cnt) := CheckWClip(vertex_i.coord.w);
                
                if r.vertex_cnt = 2 then
                    v.vertex_cnt := 0;
                    v.attrib_num := attrib_num_i;
                    v.cmd := cmd_i;
                    if v.need_clipping = "000" then
                        -- no need for w clip, start 1/w calc
                        v.state := CALC_W_RECIPROCAL;
                        v.reciprocal_data := r.polygon(0).coord.w;
                        v.reciprocal_stb := '1';
                    elsif v.need_clipping = "111" then
                        -- polygon is fully out of view space 
                        -- and should be discarded, just stay in this state
                        null;
                    else
                        -- perform w clip
                        v.state := CLIP_F_0;
                        v.clip_prev_vertex := 2;
                        v.clip_vertex := 0;
                        v.clip_new_vertex := 0;
                    end if;
                else
                    v.vertex_cnt := r.vertex_cnt + 1;
                end if;
            end if;
            
        ----------------------------------------------------------------
        --               Clipping FSM part starts here                --
        ----------------------------------------------------------------
        
        -- Clipping intersection factor calc: (Wc - Wp)
        when CLIP_F_0 =>

            if r.need_clipping(r.clip_vertex) /= r.need_clipping(r.clip_prev_vertex) then
                -- edge needs clipping
                v.fmac_a := r.polygon(r.clip_vertex).coord.w;
                v.fmac_b := ONE32;
                v.fmac_c := float_invert_sign(r.polygon(r.clip_prev_vertex).coord.w);
                v.fmac_stb := '1';
                v.state := CLIP_F_1;
            elsif r.clip_vertex /= 2 then
                v.clip_vertex := r.clip_vertex + 1;
                v.clip_prev_vertex := r.clip_vertex;
            else
                v.state := CLIP_FINISH;
            end if;
            
            if r.need_clipping(r.clip_prev_vertex) = '0' then
                -- prev vertex is valid
                v.clipped_polygon(r.clip_new_vertex) := r.polygon(r.clip_prev_vertex);
                v.clip_new_vertex := r.clip_new_vertex + 1;
            end if;

        -- Clipping intersection factor calc: (W_CLIP_VAL - Wp) and (1 /  (Wc - Wp))
        when CLIP_F_1 =>
            if fmac_ready then
                v.reciprocal_data := fmac_result;
                v.reciprocal_stb := '1';
                v.state := CLIP_F_2;
                
                v.fmac_a := W_CLIP_VAL;
                v.fmac_b := ONE32;
                v.fmac_c := float_invert_sign(r.polygon(r.clip_prev_vertex).coord.w);
                v.fmac_stb := '1';
            end if;
        
        -- Clipping intersection factor calc: f = (W_CLIP_VAL - Wp) / (Wc - Wp)  
        when CLIP_F_2 =>
            -- relies on the fact that reciprocal takes longer than FMAC
            if reciprocal_ready then
                v.fmac_a := reciprocal_result;
                v.fmac_b := fmac_result;
                v.fmac_c := ZERO32;
                v.fmac_stb := '1';
                v.state := CLIP_A_0;
            end if;
            
        -- Clipping intersection factor ready
        when CLIP_A_0 =>
            if fmac_ready then
                v.clip_ifactor := fmac_result;
                
                v.fmac_a := GetParamFromPolygon(r.polygon, r.clip_vertex, r.clip_param);
                v.fmac_b := ONE32;
                v.fmac_c := float_invert_sign(GetParamFromPolygon(r.polygon, r.clip_prev_vertex, r.clip_param));
                v.fmac_stb := '1';
                v.state := CLIP_A_1;
            end if;

        -- Clipping coord and attribute calc: An = Ap + f(Ac-Ap)
        when CLIP_A_1 =>
            if fmac_ready then
                v.fmac_a := r.clip_ifactor;
                v.fmac_b := fmac_result;
                v.fmac_c := GetParamFromPolygon(r.polygon, r.clip_prev_vertex, r.clip_param);
                v.fmac_stb := '1';
                v.state := CLIP_A_2;
            end if;
        
        -- Clipping coord and attribute calc: An = Ap + f(Ac-Ap)
        when CLIP_A_2 =>
            if fmac_ready then
                SetParamInClipPolygon(r.clip_new_vertex, r.clip_param, fmac_result);
                if r.clip_param < r.attrib_num + NCOORDS then
                    v.clip_param := r.clip_param + 1;
                    
                    v.fmac_a := GetParamFromPolygon(r.polygon, r.clip_vertex, v.clip_param);
                    v.fmac_b := ONE32;
                    v.fmac_c := float_invert_sign(GetParamFromPolygon(r.polygon, r.clip_prev_vertex, v.clip_param));
                    v.fmac_stb := '1';
                    v.state := CLIP_A_1;
                else
                    v.clipped_polygon(r.clip_new_vertex).coord.w := W_CLIP_VAL; -- set w
                    v.clip_param := 0;
                    v.clip_new_vertex := r.clip_new_vertex + 1;
                    if r.clip_vertex < 2 then
                        v.clip_vertex := r.clip_vertex + 1;
                        v.clip_prev_vertex := r.clip_vertex;
                        v.state := CLIP_F_0;
                    else
                        v.state := CLIP_FINISH;
                    end if;
                end if;
            end if;
            
        -- Clipping done
        when CLIP_FINISH =>
            -- synthesis translate_off
            assert ((r.clip_new_vertex = 3) or (r.clip_new_vertex = 4)) severity failure;
            -- synthesis translate_on
            
            if (r.clip_new_vertex = 4) then
                v.clip_add_polygon := '1';
            end if;
            
            v.polygon(0) := r.clipped_polygon(0);
            v.polygon(1) := r.clipped_polygon(1);
            v.polygon(2) := r.clipped_polygon(2);
            
            -- start 1/w calc
            v.state := CALC_W_RECIPROCAL;
            v.reciprocal_data := v.polygon(0).coord.w;
            v.reciprocal_stb := '1';
            
        ----------------------------------------------------------------
        --               Clipping FSM part ends here                  --
        ----------------------------------------------------------------
        
        -- Replace W coord with 1/W as we'll only need to divide on it
        when CALC_W_RECIPROCAL =>
            if reciprocal_ready then
                v.polygon(r.vertex_cnt).coord.w := reciprocal_result;
                v.w_ready(r.vertex_cnt) := '1';
                if r.vertex_cnt = 2 then
                    v.state := WAIT_PERSPECTIVE_DIVIDE;
                    v.vertex_cnt := 0;
                else
                    v.vertex_cnt := r.vertex_cnt + 1;
                    v.reciprocal_data := r.polygon(v.vertex_cnt).coord.w;
                    v.reciprocal_stb := '1';
                end if;
            end if;
        
        -- Just wait for FMAC outside this FSM to finish with all coord mul by 1/W   
        when WAIT_PERSPECTIVE_DIVIDE =>
            if r.w_ready = "000" then
                v.state := VIEWPORT_0;
            end if;

        -- Viewport transform ((width/2) * (x+1) + x0)
        when VIEWPORT_0 =>
            --if fmac_ready then
            v.fmac_a := r.polygon(r.vertex_cnt).coord.x;
            v.fmac_b := viewport_i.w2;
            v.fmac_c := viewport_i.x0;
            v.fmac_stb := '1';
            v.state := VIEWPORT_1;
            --end if;
        
        -- Viewport transform ((height/2) * (y+1) + y0)
        when VIEWPORT_1 =>
            if fmac_ready then
                v.polygon(r.vertex_cnt).coord.x := fmac_result;
                v.fmac_a := r.polygon(r.vertex_cnt).coord.y;
                v.fmac_b := viewport_i.h2;
                v.fmac_c := viewport_i.y0;
                v.fmac_stb := '1';
                v.state := VIEWPORT_2;
            end if;
        
        -- Viewport transform (fn2 * z + nf2)
        when VIEWPORT_2 =>
            if fmac_ready then
                v.polygon(r.vertex_cnt).coord.y := fmac_result;
                v.fmac_a := r.polygon(r.vertex_cnt).coord.z;
                v.fmac_b := viewport_i.fn2;
                v.fmac_c := viewport_i.nf2;
                v.fmac_stb := '1';
                v.state := VIEWPORT_3;
            end if;
            
        -- Finish viewport transform
        when VIEWPORT_3 =>
            if fmac_ready then
                v.polygon(r.vertex_cnt).coord.z := fmac_result;
                -- mark vertex as ready to be sent by send FSM
                v.vertex_ready(r.vertex_cnt) := '1'; 
                if r.vertex_cnt = 2 then
                    v.state := WAIT_FOR_SEND;
                    v.vertex_cnt := 0;
                else
                    v.vertex_cnt := r.vertex_cnt + 1;
                    v.state := VIEWPORT_0;
                end if;
            end if;
                
        -- Wait for whole polygon to be sent
        when WAIT_FOR_SEND =>
            if r.vertex_ready = "000" then
                if r.clip_add_polygon = '1' then
                    -- process second polygon created by clipping
                    v.clip_add_polygon := '0';
                    v.polygon(0) := r.clipped_polygon(0);
                    v.polygon(1) := r.clipped_polygon(2);
                    v.polygon(2) := r.clipped_polygon(3);
                    
                    -- start 1/w calc
                    v.state := CALC_W_RECIPROCAL;
                    v.reciprocal_data := v.polygon(0).coord.w;
                    v.reciprocal_stb := '1';
                else
                    v.state := VERTEX_INPUT;
                end if;
            end if;
    
    end case;
    
    -- Perform coords perspective divide (by multiply) in parallel to 1/W calc
    if r.persp_fmac_busy then
        if fmac_ready then
            SetCoordInPolygon(r.persp_vertex, r.persp_coord, fmac_result);
            if r.persp_coord /= 2 then
                v.persp_coord := r.persp_coord + 1;
                v.fmac_a := GetCoordFromPolygon(r.polygon, r.persp_vertex, v.persp_coord);
                if r.persp_coord = 0 then
                    v.fmac_c := ONE32;  -- add 1.0 to x and y as a first step of viewport transform
                else
                    v.fmac_c := ZERO32;
                end if;
                v.fmac_stb := '1';
            else
                v.persp_coord := 0;
                v.w_ready(r.persp_vertex) := '0';
                v.persp_fmac_busy := '0';
                
                if r.persp_vertex /= 2 then
                    v.persp_vertex := r.persp_vertex + 1;
                else
                    v.persp_vertex  := 0;
                end if;
            end if;
        end if;
    elsif r.w_ready(r.persp_vertex) then
        v.fmac_a := GetCoordFromPolygon(r.polygon, r.persp_vertex, r.persp_coord);
        v.fmac_b := r.polygon(v.persp_vertex).coord.w;
        v.fmac_c := ONE32;  -- add 1.0 to x and y as a first step of viewport transform
        v.fmac_stb := '1';
        v.persp_fmac_busy := '1';
    end if;
  
    case r.send_state is
    
        -- Wait for first vertex to become ready & send command
        when SEND_IDLE =>
            v.send_last := '0';
            if r.vertex_ready(0) then
                v.send_valid := '1';
                v.send_data := r.cmd;
                v.send_state := SEND_WAIT_READY;
            end if; 
    
        -- Wait for ready
        when SEND_WAIT_READY =>
            if ready_i then
                v.send_valid := '0';
                v.send_state := SEND_COORDS_0;
            end if;
        
        -- When vertex becomes ready - start sending coords    
        when SEND_COORDS_0 =>
            if r.vertex_ready(r.send_vertex) then
                v.send_valid := '1';
                v.send_data := GetCoordFromPolygon(r.polygon, r.send_vertex, 0);
                v.send_state := SEND_COORDS_1;
            end if;
            
        -- Send vertex coords
        when SEND_COORDS_1 =>
            if ready_i then
                if r.send_cnt = 3 then
                    v.send_cnt := 0;
                    v.send_state := SEND_ATTRIBS;
                    v.send_data := r.polygon(v.send_vertex).attr(0);
                else
                    v.send_cnt := r.send_cnt + 1;
                    v.send_data := GetCoordFromPolygon(r.polygon, r.send_vertex, v.send_cnt);
                end if;
            end if;
            
        -- Send vertex attributes
        when SEND_ATTRIBS =>
            if ready_i then
                if r.send_cnt = r.attrib_num then
                    v.send_cnt := 0;
                    v.send_valid := '0';
                    v.vertex_ready(r.send_vertex) := '0';
                    if r.send_vertex = 2 then
                        v.send_state := SEND_IDLE;
                        v.send_vertex := 0;
                    else
                        v.send_vertex := r.send_vertex + 1;
                        v.send_data := GetCoordFromPolygon(r.polygon, v.send_vertex, 0);
                        v.send_state := SEND_COORDS_0;
                    end if;
                else
                    v.send_cnt := r.send_cnt + 1;
                    v.send_data := r.polygon(r.send_vertex).attr(v.send_cnt);
                    if (v.send_cnt = r.attrib_num) and (r.send_vertex = 2) then
                        v.send_last := '1';
                    end if;
                    
                end if;
            end if;
    end case;
    
    rin <= v;
    
end process;
    
end architecture behavioral;
