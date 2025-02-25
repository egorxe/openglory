------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- VHDL package for global GPU project definitions & helpers
--
------------------------------------------------------------------------
------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.float_pkg.all;

use work.gpu_config_pkg.all;

package gpu_pkg is


    ------------------------------------------------------------------------
    ---------------------------- CONSTANTS ---------------------------------
    ------------------------------------------------------------------------

    -- General useful constants
    constant ZERO32                 : std_logic_vector(31 downto 0) := (others => '0');
    
    constant NCOORDS                : integer           := 3;
    constant NWCOORDS               : integer           := 4;
    constant NCOLORS                : integer           := 4;
    constant NVERTICES              : integer           := 3;
    constant NTEXCOORD              : integer           := 2;
    constant NVERTEX_ATTR           : integer           := NCOLORS+NTEXCOORD;
    constant MAX_RESOLUTION_POW     : integer           := 10;      
    constant MAX_RESOLUTION         : integer           := 2**MAX_RESOLUTION_POW;
    
    -- General float constants
    constant FLOAT_WDT              : integer           := 32;
    constant FLOAT_SIGN_WDT         : integer           := 1;
    constant FLOAT_EXP_WDT          : integer           := 8;
    constant FLOAT_MANT_WDT         : integer           := 23;
    
    constant FLOAT_SIGN             : integer           := 31;
    constant FLOAT_EXP_HI           : integer           := FLOAT_SIGN-1;                -- 30
    constant FLOAT_EXP_LO           : integer           := FLOAT_EXP_HI-FLOAT_EXP_WDT+1;-- 23
    constant FLOAT_MANT_HI          : integer           := FLOAT_EXP_LO-1;              -- 22
    constant FLOAT_MANT_LO          : integer           := 0;
    
    -- Usefull float constants
    constant ZF                     : float32                       := to_float(0);
    constant HALF32                 : std_logic_vector(31 downto 0) := ("0" & "01111110" & "00000000000000000000000");
    constant ONE32                  : std_logic_vector(31 downto 0) := ("0" & "01111111" & "00000000000000000000000");
    constant TWO32                  : std_logic_vector(31 downto 0) := ("0" & "10000000" & "00000000000000000000000");
    constant MINUSONE32             : std_logic_vector(31 downto 0) := ("1" & "01111111" & "00000000000000000000000");
    constant MINUSTWO32             : std_logic_vector(31 downto 0) := ("1" & "10000000" & "00000000000000000000000");
    constant FL32_255               : std_logic_vector(31 downto 0) := ("0" & "10000110" & "11111110000000000000000");
    constant FL32_640               : std_logic_vector(31 downto 0) := to_slv(to_float(real(640)));
    constant FL32_480               : std_logic_vector(31 downto 0) := to_slv(to_float(real(480)));
    
    -- Configuration values from board config package
    constant BOARD_NAME             : string                        := work.gpu_config_pkg.BOARD_NAME;
    constant CAPABILITIES           : std_logic_vector(31 downto 0) := work.gpu_config_pkg.CAPABILITIES;
    constant FAST_CLEAR             : boolean                       := work.gpu_config_pkg.FAST_CLEAR;
    constant TEXTURING_UNITS        : integer                       := work.gpu_config_pkg.TEXTURING_UNITS;
    constant SCREEN_WIDTH           : integer                       := work.gpu_config_pkg.SCREEN_WIDTH;
    constant SCREEN_HEIGHT          : integer                       := work.gpu_config_pkg.SCREEN_HEIGHT;
    constant FB_BASE_REG            : std_logic_vector(31 downto 0) := work.gpu_config_pkg.FB_BASE_REG;
    constant DRAM_BASE_ADDR         : std_logic_vector(31 downto 0) := work.gpu_config_pkg.DRAM_BASE_ADDR;
    constant FB_BASE_ADDR0          : std_logic_vector(31 downto 0) := work.gpu_config_pkg.FB_BASE_ADDR0;
    constant FB_BASE_ADDR1          : std_logic_vector(31 downto 0) := work.gpu_config_pkg.FB_BASE_ADDR1;
    constant ZBUF_BASE_ADDR         : std_logic_vector(31 downto 0) := work.gpu_config_pkg.ZBUF_BASE_ADDR;
    
    -- Stream constants
    constant GLOBAL_AXIS_DATA_WIDTH : integer                       := 32;
    constant GLOBAL_AXIS_KEEP_WIDTH : integer                       := 4;
    constant GLOBAL_AXIS_ID_WIDTH   : integer                       := 4;
    constant GLOBAL_AXIS_DEST_WIDTH : integer                       := 4;
    constant GLOBAL_AXIS_USER_WIDTH : integer                       := 4;
                
    -- Wishbone constants              
    constant WB_ADDR_WIDTH          : integer                       := 32;
    constant WB_DATA_WIDTH          : integer                       := 32;

    ------------------------------------------------------------------------
    ------------------------------ TYPES -----------------------------------
    ------------------------------------------------------------------------

    subtype vec32 is std_logic_vector(31 downto 0);
    type V2 is array (0 to 1) of vec32;
    type V3 is array (0 to 2) of vec32;
    type V4 is array (0 to 3) of vec32;
    type M44 is array (0 to 3) of V4;
    type FV4 is array (0 to 3) of float32;
    type FM44 is array (0 to 3) of FV4;

    constant V4_ZERO32 : V4 := (ZERO32, ZERO32, ZERO32, ZERO32);
    constant M44_ZERO32 : M44 := (V4_ZERO32, V4_ZERO32, V4_ZERO32, V4_ZERO32);
    constant M44_ID : M44 := (
        (ONE32, ZERO32, ZERO32, ZERO32),
        (ZERO32, ONE32, ZERO32, ZERO32),
        (ZERO32, ZERO32, ONE32, ZERO32),
        (ZERO32, ZERO32, ZERO32, ONE32)
    );

    subtype vecaxisdata is std_logic_vector(GLOBAL_AXIS_DATA_WIDTH - 1 downto 0);
    
    -- AXI-stream
    type global_axis_mosi_type is record
        axis_tdata            : std_logic_vector(GLOBAL_AXIS_DATA_WIDTH - 1 downto 0);
        axis_tkeep            : std_logic_vector(GLOBAL_AXIS_KEEP_WIDTH - 1 downto 0);
        axis_tvalid           : std_logic;
        axis_tlast            : std_logic;
        axis_tid              : std_logic_vector(GLOBAL_AXIS_ID_WIDTH - 1 downto 0);
        axis_tdest            : std_logic_vector(GLOBAL_AXIS_DEST_WIDTH - 1 downto 0);
        axis_tuser            : std_logic_vector(GLOBAL_AXIS_USER_WIDTH - 1 downto 0);
    end record;
    
    constant AXIS_MOSI_DEFAULT : global_axis_mosi_type := 
    (
        axis_tdata            => (others => '0'),
        axis_tkeep            => (others => '0'),
        axis_tvalid           => '0',
        axis_tlast            => '0',
        axis_tid              => (others => '0'),
        axis_tdest            => (others => '0'),
        axis_tuser            => (others => '0')  
    );
    
    type global_axis_miso_type is record
        axis_tready           : std_logic;
    end record;
    
    constant AXIS_MISO_DEFAULT : global_axis_miso_type := (axis_tready => '0');
    
    -- Wishbone
    constant WB_DAT_WDT     : integer := 32;
    constant WB_ADDR_WDT    : integer := 32;
    
    type wishbone_mosi_type is record
        wb_adr      : std_logic_vector(WB_ADDR_WDT-1 downto 0);
        wb_dato     : std_logic_vector(WB_DAT_WDT-1 downto 0);
        wb_sel      : std_logic_vector((WB_DAT_WDT/8)-1 downto 0);
        wb_stb      : std_logic;
        wb_cyc      : std_logic;
        wb_we       : std_logic;
    end record;
    
    type wishbone_miso_type is record
        wb_dati     : std_logic_vector(WB_DAT_WDT-1 downto 0);
        wb_ack      : std_logic;
    end record;
    
    -- Point types with different sets of coords & attributes
    type point_coord_type is record
        x       : vec32;
        y       : vec32;
        z       : vec32;
    end record;
    
    type point_wcoord_type is record
        x       : vec32;
        y       : vec32;
        z       : vec32;
        w       : vec32;
    end record;

    type point_colors_type is record
        r       : vec32;
        g       : vec32;
        b       : vec32;
    end record;

    type point_acolors_type is record
        r       : vec32;
        g       : vec32;
        b       : vec32;
        a       : vec32;
    end record;

    type point_type is record
        x       : vec32;
        y       : vec32;
        z       : vec32;
        w       : vec32;
        r       : vec32;
        g       : vec32;
        b       : vec32;
        a       : vec32;
    end record;
    
    subtype attrib_num_type is integer range 0 to NVERTEX_ATTR-1;
    subtype vertex_num_type is integer range 0 to NVERTICES-1;
    
    -- Texture float coords
    type vertex_attr_type is array (0 to NVERTEX_ATTR-1) of vec32;

    -- Vertex with up to 6 attribures (4 colors + 2 tex coords)
    type full_vertex_type is record
        coord   : point_wcoord_type;
        attr    : vertex_attr_type;
    end record;
 
    -- Point with texture coords for complete polygon
    type full_polygon_type is array (0 to NVERTICES-1) of full_vertex_type;

    ------------------------------------------------------------------------
    ---------------------------- CONSTANTS2 --------------------------------
    ------------------------------------------------------------------------

    -- Z-buffer depth in bits
    constant ZDEPTH_WDT                     : integer := 24;
    constant PIPELINE_MAX_Z                 : vec32 := std_logic_vector(to_unsigned((2**ZDEPTH_WDT)-1,32)); --2^16 - 1
    constant PIPELINE_MAX_Z_FL32            : vec32 := to_slv(to_float(real((2**ZDEPTH_WDT)-1)));

    -- Pipeline commands
    constant GPU_PIPE_CMD_POLY_VERTEX3      : vec32 := X"FFFF1500";
    constant GPU_PIPE_CMD_POLY_VERTEX4      : vec32 := X"FFFF1800";
    constant GPU_PIPE_CMD_POLY_VERTEX3N3    : vec32 := X"FFFF1801";
    constant GPU_PIPE_CMD_POLY_VERTEX4N3    : vec32 := X"FFFF1B01";
    constant GPU_PIPE_CMD_POLY_VERTEX3TC    : vec32 := X"FFFF1B02";
    constant GPU_PIPE_CMD_POLY_VERTEX4TC    : vec32 := X"FFFF1E02";
    constant GPU_PIPE_CMD_SYNC              : vec32 := X"FFFF0010";
    constant GPU_PIPE_CMD_CLEAR_FB          : vec32 := X"FFFF0011";
    constant GPU_PIPE_CMD_CLEAR_ZB          : vec32 := X"FFFF0012";
    constant GPU_PIPE_CMD_FRAGMENT          : vec32 := X"FFFF0320";
    constant GPU_PIPE_CMD_TEXFRAGMENT       : vec32 := X"FFFF0421";
    constant GPU_PIPE_CMD_MODEL_MATRIX      : vec32 := X"FFFF1030";
    constant GPU_PIPE_CMD_PROJ_MATRIX       : vec32 := X"FFFF1031";
    constant GPU_PIPE_CMD_RAST_STATE        : vec32 := X"FFFF0140";
    constant GPU_PIPE_CMD_FRAG_STATE        : vec32 := X"FFFF0141";
    constant GPU_PIPE_CMD_LIGHT_STATE       : vec32 := X"FFFF0142";
    constant GPU_PIPE_CMD_VIEWPORT_PARAMS   : vec32 := X"FFFF0650";
    constant GPU_PIPE_CMD_LIGHT_PARAMS      : vec32 := X"FFFF0851";
    constant GPU_PIPE_CMD_BLEND_PARAMS      : vec32 := X"FFFF0152";
    constant GPU_PIPE_CMD_BINDTEXTURE       : vec32 := X"FFFF0260";
    constant GPU_PIPE_CMD_NOP               : vec32 := X"FFFF00F0";

    constant GPU_PIPE_MASK_CMD              : vec32 := X"FFFF0000";
    
    -- State command bits
    constant GPU_STATE_RAST_CULL_HI         : integer := 1;
    constant GPU_STATE_RAST_CULL_LO         : integer := 0;
    
    -- Point types
    constant ZERO_POINT_COORD   : point_coord_type  := (ZERO32, ZERO32, ZERO32);
    constant ZERO_POINT_WCOORD  : point_wcoord_type := (ZERO32, ZERO32, ZERO32, ZERO32);
    constant ZERO_POINT_COLORS  : point_colors_type := (ZERO32, ZERO32, ZERO32);
    constant ZERO_POINT         : point_type := (ZERO32, ZERO32, ZERO32, ZERO32, ZERO32, ZERO32, ZERO32, ZERO32);
    -- Polygon types
    constant ZERO_VERTEX_ATTR   : vertex_attr_type  := (others => ZERO32);
    constant ZERO_FULL_VERTEX   : full_vertex_type  := (ZERO_POINT_WCOORD, ZERO_VERTEX_ATTR);
    constant ZERO_FULL_POLYGON  : full_polygon_type := (ZERO_FULL_VERTEX, ZERO_FULL_VERTEX, ZERO_FULL_VERTEX);

    ------------------------------------------------------------------------
    ---------------------------- FUNCTIONS ---------------------------------
    ------------------------------------------------------------------------

    ----------------------------------------------------------------------------
    -- CONVERSIONS
    ----------------------------------------------------------------------------

    function tf(x : real) return float32; -- alias with shorter name for real->float32
    function itf(x : integer) return float32;
    function tfs(x : std_logic_vector) return float32;
    
    function to_sl(b : boolean) return std_logic;                                       -- boolean->std_logic
    function to_slv(a : integer; size : natural) return std_logic_vector;               -- integer->std_logic_vector
    function to_s_slv(intValue : integer; vecLength : integer) return std_logic_vector; -- integer->std_logic_vector
    function to_slv(value : real) return std_logic_vector;                              -- real->std_logic_vector
    function to_slv(c : character) return std_logic_vector;                             -- character->std_logic_vector

    function to_vec32(a : integer) return std_logic_vector; -- integer->std_logic_vector 32 bit
    function to_vec32(a : float32) return std_logic_vector; -- float32->std_logic_vector 32 bit (cut to unsigned??)
    function to_vec32(a : real) return std_logic_vector;

    function to_uint(a : std_logic_vector) return integer;  -- std_logic_vector->unsigned integer
    function to_uint(a : std_logic) return integer;         -- std_logic_vector->unsigned integer
    function to_uint(a : float32) return integer;           -- float32->unsigned integer
    function to_sint(a : std_logic_vector) return integer;  -- std_logic_vector->signed integer

    function to_real(value : std_logic_vector) return real; -- std_logic_vector->real

    ----------------------------------------------------------------------------
    -- OTHER
    ----------------------------------------------------------------------------

    function zero_vec(size     : integer) return std_logic_vector;  -- create vector of all zeroes
    function max_vec(size : integer) return std_logic_vector;       -- create vector of all ones
    function extr_vec(v : std_logic_vector; size : integer) return std_logic_vector;    -- extend vector with zeroes (right)
    function extl_vec(v : std_logic_vector; size : integer) return std_logic_vector;    -- extend vector with zeroes (left)

    function is_all_0(x : std_logic_vector) return boolean;     -- compares all bits with 1
    function is_all_1(x : std_logic_vector) return boolean;     -- compares all bits with 0
    function count_ones(x : std_logic_vector) return integer;   -- count number of '1' bits
    function or_all(x : std_logic_vector) return std_logic;     -- OR all bits
    function is_x(v : std_logic) return boolean;            -- check that signal is not 1 or 0
    function has_x(v : std_logic_vector) return boolean;    -- check that vector has non 1 or 0 values

    function equal(x1 : vec32; x2 : vec32) return boolean;      -- comparing as float32
    function less(x1 : vec32; x2 : vec32) return boolean;
    function more(x1 : vec32; x2 : vec32) return boolean;
    function lessEq(x1 : vec32; x2 : vec32) return boolean;
    function moreEq(x1 : vec32; x2 : vec32) return boolean;
    function fmin(x1 : vec32; x2 : vec32) return vec32;         -- find answer as float32
    function fmax(x1 : vec32; x2 : vec32) return vec32;
    
    function uadd(x : std_logic_vector; y : integer) return std_logic_vector;

    function log2(depth : natural) return integer;
    
    function float_exp(v : vec32) return integer;
    function float_mant(v : vec32) return integer;
    function float_invert_sign(v : vec32) return vec32;
    function float_less_than_zero(v : vec32) return boolean;
    function float_less_or_equal_zero(v : vec32) return boolean;
    function float_more_than_one(v : vec32) return boolean;
    
    function cmd_num_args(cmd : vec32) return integer;

end gpu_pkg;


------------------------------------------------------------------------
--------------------------- PACKAGE BODY -------------------------------
------------------------------------------------------------------------

package body gpu_pkg is

    ----------------------------------------------------------------------------
    -- CONVERSIONS
    ----------------------------------------------------------------------------

    ----------------------------------to float32------------------------------------------------

    function tf(x : real) return float32 is
    begin
        return to_float(x);
    end;
    
    function itf(x : integer) return float32 is
    begin
        return to_float(x);
    end;

    function tfs(x : std_logic_vector) return float32 is
    begin
        return to_float(x);
    end;

    ----------------------------------to std_logic_vector------------------------------------------------
    
    function to_sl(b : boolean) return std_logic is
    begin
        if b then
            return '1';
        else
            return '0';
        end if;
    end function;

    function to_slv(a : integer; size : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(a, size));
    end;

    function to_slv(value : real) return std_logic_vector is
    begin
        return to_slv(tf(value));
    end function;

    function to_slv(c : character) return std_logic_vector is
    begin
        return to_slv(character'pos(c), 8);
    end function;

    function to_s_slv(intValue : integer; vecLength : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(intValue, vecLength));
    end function;

    ---------------------------------to vec32------------------------------------------------

    function to_vec32(a : integer) return std_logic_vector is
    begin
        return to_slv(a, 32);
    end;

    function to_vec32(a : float32) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(a, 32));
    end;

    function to_vec32(a : real) return std_logic_vector is
    begin
        return to_slv(tf(a));
    end;

    ----------------------------------to integer------------------------------------------------


    function to_uint(a : std_logic_vector) return integer is
    begin
        return to_integer(unsigned(a));
    end;

    function to_uint(a : std_logic) return integer is
        variable buff : std_logic_vector(1 downto 0);
    begin
        buff := '0' & a;
        return to_integer(unsigned(buff));
    end;

    function to_uint(a : float32) return integer is
    begin
        return to_uint(to_vec32(a));
    end;

    function to_sint(a : std_logic_vector) return integer is
    begin
        return to_integer(signed(a));
    end;

    ----------------------------------to real------------------------------------------------

    function to_real(value : std_logic_vector) return real is
    begin
        return to_real(to_float(value));
    end function;

    ----------------------------------------------------------------------------
    -- OTHER
    ----------------------------------------------------------------------------
    
    -----------------------------------helpers------------------------------------------

    function zero_vec(size : integer) return std_logic_vector is
    begin
        return to_slv(0, size);
    end;

    function max_vec(size : integer) return std_logic_vector is
    begin
        return to_s_slv(-1, size);
    end function;
    
    -- extend vector with zeroes (right)
    function extr_vec(v : std_logic_vector; size : integer) return std_logic_vector is
    begin
        if v'length = size then
            return v;
        else
            return v & zero_vec(size - v'length);
        end if;
    end function;
    
    -- extend vector with zeroes (left)
    function extl_vec(v : std_logic_vector; size : integer) return std_logic_vector is
    begin
        if v'length = size then
            return v;
        else
            return zero_vec(size - v'length) & v;
        end if;
    end function;
    
    function is_all_0(x : std_logic_vector
        ) return boolean is
    begin
        for i in 0 to x'length - 1 loop
            if (x(i) = '0') then
                return false;
            end if;
        end loop;

        return true;
    end function;

    function is_all_1(x : std_logic_vector
        ) return boolean is
    begin
        for i in 0 to x'length - 1 loop
            if (x(i) = '1') then
                return false;
            end if;
        end loop;

        return true;
    end function;

    function count_ones(x : std_logic_vector) return integer is
        variable r : integer := 0;
    begin
        for i in 0 to x'length - 1 loop
            if (x(i) = '1') then
                r := r + 1;
            end if;
        end loop;

        return r;
    end function;

    function or_all(x : std_logic_vector) return std_logic is
        variable r : std_logic := '0';
    begin
        for i in x'range loop
            r := r or x(i);
        end loop;

        return r;
    end function;
    
    function is_x(v : std_logic) return boolean is          -- check that signal is not 1 or 0
    begin
        return not ((v = '1') or (v = '0'));
    end function;
    
    function has_x(v : std_logic_vector) return boolean is  -- check that vector has non 1 or 0 values
    begin
        for i in v'range loop
            if is_x(v(i)) then
                return True;
            end if;
        end loop;
        return False;
    end function;

    -----------------------------------float 32 logic-----------------------------------------
    function equal(
        x1 : vec32;
        x2 : vec32
        ) return boolean is
    begin
        --special case for zeros with different signs
        if (x1(30 downto 0) = zero_vec(31) and x2(30 downto 0) = zero_vec(31)) then
            return true;
        end if;

        comparing : for i in x1'length - 1 downto 0 loop
            if (x1(i) /= x2(i)) then
                return false;
            end if;
        end loop;

        return true;
    end function;

    function less(
        x1 : vec32;
        x2 : vec32
    ) return boolean is
    begin
        --special case for zeros with different signs
        if (x1(30 downto 0) = zero_vec(31) and x2(30 downto 0) = zero_vec(31)) then
            return false;
        end if;

        if (x1(31) > x2(31)) then --sign
            return true;
        elsif(x1(31) < x2(31)) then
            return false;
        end if;

        comparing : for i in 30 downto 0 loop
            if (x1(i) < x2(i)) then --absolute value of x1 < x2
                if (x1(31) = '1') then --negative numbers
                    return false;
                else --positive numbers
                    return true;
                end if;    

            elsif(x1(i) > x2(i)) then --absolute value of x1 > x2
                if (x1(31) = '1') then --negative numbers
                    return true;
                else --positive numbers 
                    return false;
                end if;
            end if;
        end loop comparing;

        return false;
    end;    

    function more(
        x1 : vec32;
        x2 : vec32
    ) return boolean is
    begin
        --special case for zeros with different signs
        if (x1(30 downto 0) = zero_vec(31) and x2(30 downto 0) = zero_vec(31)) then
            return false;
        end if;

        if (x1(31) < x2(31)) then --sign
            return true;
        elsif(x1(31) > x2(31)) then
            return false;
        end if;

        comparing : for i in 30 downto 0 loop
            if (x1(i) > x2(i)) then --absolute value of x1 > x2
                if (x1(31) = '1') then --negative numbers
                    return false;
                else --positive numbers
                    return true;
                end if;    

            elsif(x1(i) < x2(i)) then --absolute value of x1 < x2
                if (x1(31) = '1') then --negative numbers
                    return true;
                else --positive numbers 
                    return false;
                end if;
            end if;
        end loop comparing;

        return false;
    end;   

    function lessEq (
        x1: vec32;
        x2: vec32
     ) return boolean is
     begin
         return less(x1, x2) or equal(x1, x2);
     end function lessEq; 

    function moreEq (
        x1: vec32;
        x2: vec32
     ) return boolean is
     begin
         return more(x1, x2) or equal(x1, x2);
     end function moreEq; 

    function fmin(
        x1 : vec32;
        x2 : vec32
    ) return vec32 is
    begin
        if less(x1, x2) then return x1;
        else return x2;
        end if;
    end;

    function fmax(
        x1 : vec32;
        x2 : vec32
    ) return vec32 is
    begin
        if more(x1, x2) then return x1;
        else return x2;
        end if;
    end;

    function log2( depth : natural) return integer is
        variable temp    : integer := depth;
        variable ret_val : integer := 0;

    begin
        while temp > 1 loop
            ret_val := ret_val + 1;
            temp    := temp / 2;
        end loop;

        return ret_val;
    end function;
    
    function uadd(x : std_logic_vector; y : integer) return std_logic_vector is
    begin
        return std_logic_vector(unsigned(x) + y);
    end;
    
    function float_exp(v : vec32) return integer is
    begin
        return to_uint(v(FLOAT_EXP_HI downto FLOAT_EXP_LO));
    end function;
    
    function float_mant(v : vec32) return integer is
    begin
        return to_uint(v(FLOAT_MANT_HI downto FLOAT_MANT_LO));
    end function;
    
    function float_invert_sign(v : vec32) return vec32 is
    begin
        return not v(FLOAT_SIGN) & v(FLOAT_EXP_HI downto 0);
    end function;
    
    function float_less_than_zero(v : vec32) return boolean is
    begin
        return v(FLOAT_SIGN) = '1';
    end function;
    
    function float_less_or_equal_zero(v : vec32) return boolean is
    begin
        return float_less_than_zero(v) or (v = ZERO32);
    end function;
    
    function float_more_than_one(v : vec32) return boolean is
    begin
        return  (v(FLOAT_SIGN) = '0') and 
                ((float_exp(v) > 127) or ((float_exp(v) = 127) and (float_mant(v) /= 0)));
    end function;
    
    function cmd_num_args(cmd : vec32) return integer is
    begin
        return to_uint(cmd(15 downto 8));
    end function;

end gpu_pkg;
