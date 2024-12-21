------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- VHDL package for rasterizer pipeline definitions
--
------------------------------------------------------------------------
------------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.std_logic_unsigned.all;
    use ieee.float_pkg.all;

    use work.gpu_pkg.all;
    
package rast_pipe_pkg is

------------------------------------------------------------------------
---------------------------- CONSTANTS ---------------------------------
------------------------------------------------------------------------

    constant EDGE_FUNC_CNT          : integer := 3;
    constant SCREEN_COORD_WDT       : integer := MAX_RESOLUTION_POW;
    constant EDGE_UNITS_POW         : integer := 0;
    constant EDGE_UNITS             : integer := 2**EDGE_UNITS_POW;
    constant BARY_UNITS_PER_EDGE    : integer := 1;
    constant TOTAL_BARY_UNITS       : integer := EDGE_UNITS*BARY_UNITS_PER_EDGE;

------------------------------------------------------------------------
----------------------------   TYPES   ---------------------------------
------------------------------------------------------------------------

    subtype screen_coord_vec is std_logic_vector(SCREEN_COORD_WDT-1 downto 0);
    subtype zdepth_vec is std_logic_vector(ZDEPTH_WDT-1 downto 0);
    type screen_coord_array is array (0 to EDGE_UNITS-1) of screen_coord_vec;
    
    -- Rectangle with integer coords
    type rect_coord_type is record
        x_min   : screen_coord_vec;
        y_min   : screen_coord_vec;
        x_max   : screen_coord_vec;
        y_max   : screen_coord_vec;
    end record;
    
    -- Point with int coords
    type screen_point_type is record
        x       : screen_coord_vec;
        y       : screen_coord_vec;
    end record;
        
    -- Fragment (screen coord + z depth + color)
    type fragment_type is record
        x       : screen_coord_vec;
        y       : screen_coord_vec;
        z       : zdepth_vec;
        argb    : vec32;
    end record;
    
    type fragment_full_type is record
        x       : screen_coord_vec;
        y       : screen_coord_vec;
        z       : zdepth_vec;
        argb    : vec32;
        tx      : vec32;
        ty      : vec32;
    end record;
    
    subtype fragment_vec is std_logic_vector(SCREEN_COORD_WDT*2+ZDEPTH_WDT+32-1 downto 0);
    subtype fragment_full_vec is std_logic_vector(SCREEN_COORD_WDT*2+ZDEPTH_WDT+32*3-1 downto 0);
    type fragment_array is array (0 to BARY_UNITS_PER_EDGE-1) of fragment_full_type;
    
    -- Point with float coords array for polygon
    type point_coord_array is array (0 to 2) of point_coord_type;

    -- Array of points with float coords, weights, colors and alpha-channel for polygon
    type point_array is array (0 to 2) of point_type;
    
    -- Polygon with float coords
    type polygon_coord_type is record
        v       : point_coord_array;
    end record;

    type point_colors_array is array(0 to 2) of point_colors_type;
    type polygon_colors_type is record
        v : point_colors_array;
    end record;

    type polygon_type is record
        v       : point_array;
    end record;
    
    -- Edge functions output
    type edge_func_out_array is array (0 to EDGE_FUNC_CNT-1) of vec32;
    type pipe_edge_out_type is record
        ef          : edge_func_out_array;
        p           : screen_point_type;
        new_polygon : std_logic;
    end record;
    
    -- Precomputation stage outputs
    type precomp_data_out_type is record
        polygon     : full_polygon_type;
        area_recip  : vec32;
        attr_num    : attrib_num_type;
    end record;
    
    -- Increment <-> Edge stages
    type incr_to_edge_type is record
        point           : point_coord_type;
        point_int       : screen_point_type;
        same_line       : std_logic;
        polygon_done    : std_logic;
    end record;
    
    type edge_to_incr_type is record
        next_coord      : std_logic;
        line_done       : std_logic;
        no_next_poly    : std_logic;
        done_ack        : std_logic;
    end record;
    
    type incr_to_edge_array is array (0 to EDGE_UNITS-1) of incr_to_edge_type;
    type edge_to_incr_array is array (0 to EDGE_UNITS-1) of edge_to_incr_type;
    
    -- Edge <-> Barycentric stages
    type edge_to_bary_type is record
        edge        : pipe_edge_out_type;
        edge_done   : std_logic;
    end record;
    type edge_to_bary_array is array (0 to BARY_UNITS_PER_EDGE-1) of edge_to_bary_type;
    
    -- Barycentric -> Storage stages
    type bary_to_storage_type is record
        fragment_out    : fragment_array;
        frag_ready      : std_logic_vector(BARY_UNITS_PER_EDGE-1 downto 0);
    end record;
    type bary_to_storage_array is array (0 to EDGE_UNITS-1) of bary_to_storage_type;
    
    -- Buses for FPU unit sharing
    type rast_fpu_share_out_type is record
        reciprocal_busy     : std_logic;
        reciprocal_ready    : std_logic;
        reciprocal_result   : vec32;
    end record;
    
    type rast_fpu_share_in_type is record
        reciprocal_stb      : std_logic;
        reciprocal_data     : vec32;
    end record;
    
    type rast_fpu_share_out_array is array (0 to TOTAL_BARY_UNITS-1) of rast_fpu_share_out_type;
    type rast_fpu_share_in_array is array (0 to TOTAL_BARY_UNITS-1) of rast_fpu_share_in_type;

------------------------------------------------------------------------
---------------------------- CONSTANTS ---------------------------------
------------------------------------------------------------------------

    constant ZERO_SCREENC   : screen_coord_vec  := zero_vec(SCREEN_COORD_WDT);
    constant ZERO_ZDEPTH    : zdepth_vec        := zero_vec(ZDEPTH_WDT);
    constant ZERO_SPOINT    : screen_point_type := (ZERO_SCREENC, ZERO_SCREENC);
    constant ZERO_FRAGMENT  : fragment_type     := (ZERO_SCREENC, ZERO_SCREENC, ZERO_ZDEPTH, ZERO32);
    constant ZERO_FFRAGMENT : fragment_full_type     := (ZERO_SCREENC, ZERO_SCREENC, ZERO_ZDEPTH, ZERO32, ZERO32, ZERO32);
    constant ZERO_RECT      : rect_coord_type   := (ZERO_SCREENC, ZERO_SCREENC, ZERO_SCREENC, ZERO_SCREENC);
    constant ZERO_POLYGON_COORD     : polygon_coord_type  := (v => (others => ZERO_POINT_COORD));
    constant ZERO_POLYGON_COLORS    : polygon_colors_type := (v => (others => ZERO_POINT_COLORS));
    constant ZERO_POLYGON   : polygon_type      := (v => (others => ZERO_POINT));
    constant ZERO_EFOA      : edge_func_out_array   := (others => ZERO32);
    constant ZERO_EFOT      : pipe_edge_out_type    := (ZERO_EFOA, ZERO_SPOINT, '0');
    constant ZERO_PRECOMP   : precomp_data_out_type := (ZERO_FULL_POLYGON, ZERO32, 0);
    constant ZERO_INCR_TO_EDGE  : incr_to_edge_type := (ZERO_POINT_COORD, ZERO_SPOINT, '0', '0');
    
    constant SCREEN_640     : screen_coord_vec := to_slv(640, SCREEN_COORD_WDT);
    constant SCREEN_480     : screen_coord_vec := to_slv(480, SCREEN_COORD_WDT);


------------------------------------------------------------------------
---------------------------- FUNCTIONS ---------------------------------
------------------------------------------------------------------------

    function FloatCoord2Int(v : vec32; wdt : integer) return std_logic_vector;
    function FloatToPow2Uint(f : vec32; N : integer) return std_logic_vector;
    function Fragment2Vec(f : fragment_type) return fragment_vec;
    function Vec2Fragment(v : fragment_vec) return fragment_type;
    function Fragment2Vec(f : fragment_full_type) return fragment_full_vec;
    function Vec2Fragment(v : fragment_full_vec) return fragment_full_type;
    
    function GetAttrFromPolygon(p : polygon_type; v : vertex_num_type; a : attrib_num_type) return vec32;
    function Wcoord2Coord(p: point_wcoord_type) return point_coord_type;

end;

package body rast_pipe_pkg is

-- Float coord to onscreen int (truncate)
function FloatCoord2Int(v : vec32; wdt : integer) return std_logic_vector is
    variable result : std_logic_vector(wdt-1 downto 0);
    variable bits   : integer range 0 to 31;
begin
    -- treat everything <1 as zero
    result := zero_vec(wdt);
    if v(FLOAT_SIGN) = '0' then
        if (v(FLOAT_EXP_HI downto FLOAT_EXP_LO) > 127) then
            -- !following ugly loop is a result of GHDLs inability to synthesize commented statement!
            bits := to_uint(v(FLOAT_EXP_HI downto FLOAT_EXP_LO))-128;
            if bits < wdt-1 then
                result(bits+1) := '1';
                for i in wdt-1 downto 0 loop
                    if (i <= bits) then
                        result(i) := v(FLOAT_MANT_HI-bits+i);
                    end if;
                end loop;
            else
                result := (others => '1');
            end if;
            --result(bits+1 downto 0) := '1' & v(FLOAT_MANT_HI downto FLOAT_MANT_HI-to_uint(v(FLOAT_EXP_HI downto FLOAT_EXP_LO))-128);
        elsif v(FLOAT_EXP_HI downto FLOAT_EXP_LO) = 127 then
            result(0) := '1';   -- one is special case :(
        end if;
    end if;
    return result;
end;

-- Convert [0,1] float to N bit unsigned int as if multiplying by 2**N
-- asserts on out of range floats
-- ! this conversion is not perfect as it's not linear (1.0 is special) !
function FloatToPow2Uint(f : vec32; N : integer) return std_logic_vector is
    variable exp    : integer range 0 to 255;
    variable shift  : integer range 1 to 127;
    variable off    : integer range 0 to 127;
    variable result : std_logic_vector(N-1 downto 0);
    variable mant   : std_logic_vector(FLOAT_MANT_WDT downto 0);
begin
    exp := to_uint(f(FLOAT_EXP_HI downto FLOAT_EXP_LO));
    if (f = ONE32) then
        result := max_vec(N);
    elsif f(FLOAT_SIGN-1 downto 0) = zero_vec(FLOAT_WDT-1) then
        -- +-0
        result := zero_vec(N);
    else
        -- synthesis translate_off
        --assert((exp < 127) and (f(FLOAT_SIGN) = '0')) report "FloatToPow2Uint float out of range " & to_string(to_real(f)) severity failure;
        -- synthesis translate_on
        shift := 127 - exp;
        mant := "1" & f(FLOAT_MANT_HI downto FLOAT_MANT_LO);
        
        for i in N-1 downto 0 loop
            off := i+(FLOAT_MANT_WDT-N+shift);
            if (off >= 0) and (off <= FLOAT_MANT_WDT) then
                result(i) := mant(off);
            else
                result(i) := '0';
            end if;
        end loop;
    end if;
    
    return result;
end;

function Fragment2Vec(f : fragment_type) return fragment_vec is
begin
    return f.argb & f.z & f.y & f.x;
end function;

function Fragment2Vec(f : fragment_full_type) return fragment_full_vec is
begin
    return f.ty & f.tx & f.argb & f.z & f.y & f.x;
end function;

function Vec2Fragment(v : fragment_vec) return fragment_type is
    variable f : fragment_type;
begin
    f.x := v(SCREEN_COORD_WDT-1 downto 0);
    f.y := v(SCREEN_COORD_WDT*2-1 downto SCREEN_COORD_WDT);
    f.z := v(SCREEN_COORD_WDT*2+ZDEPTH_WDT-1 downto SCREEN_COORD_WDT*2);
    f.argb := v(SCREEN_COORD_WDT*2+ZDEPTH_WDT+32-1 downto SCREEN_COORD_WDT*2+ZDEPTH_WDT);
    return f;
end function;

function Vec2Fragment(v : fragment_full_vec) return fragment_full_type is
    variable f : fragment_full_type;
begin
    f.x := v(SCREEN_COORD_WDT-1 downto 0);
    f.y := v(SCREEN_COORD_WDT*2-1 downto SCREEN_COORD_WDT);
    f.z := v(SCREEN_COORD_WDT*2+ZDEPTH_WDT-1 downto SCREEN_COORD_WDT*2);
    f.argb := v(SCREEN_COORD_WDT*2+ZDEPTH_WDT+32-1 downto SCREEN_COORD_WDT*2+ZDEPTH_WDT);
    f.tx := v(SCREEN_COORD_WDT*2+ZDEPTH_WDT+64-1 downto SCREEN_COORD_WDT*2+ZDEPTH_WDT+32);
    f.ty := v(SCREEN_COORD_WDT*2+ZDEPTH_WDT+96-1 downto SCREEN_COORD_WDT*2+ZDEPTH_WDT+64);
    return f;
end function;

function GetAttrFromPolygon(p : polygon_type; v : vertex_num_type; a : attrib_num_type) return vec32 is
begin
    case a is
        when 0 =>
            return p.v(v).r;
        when 1 =>
            return p.v(v).g;
        when others =>
            return p.v(v).b;
    end case;
end function;

function Wcoord2Coord(p: point_wcoord_type) return point_coord_type is
begin
    return (p.x, p.y, p.z);
end function;

end rast_pipe_pkg;
