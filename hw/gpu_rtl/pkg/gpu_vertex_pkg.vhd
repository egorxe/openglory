------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- VHDL package for vertex transform definitions
--
------------------------------------------------------------------------
------------------------------------------------------------------------


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.std_logic_unsigned.all;

    use work.gpu_pkg.all;
    
package gpu_vertex_pkg is

------------------------------------------------------------------------
---------------------------- CONSTANTS ---------------------------------
------------------------------------------------------------------------

------------------------------------------------------------------------
----------------------------   TYPES   ---------------------------------
------------------------------------------------------------------------

    -- Viewport params record
    type viewport_params is record
        x0  : vec32;
        y0  : vec32;
        w2  : vec32;
        h2  : vec32;
        fn2 : vec32;
        nf2 : vec32;
    end record;

------------------------------------------------------------------------
---------------------------- CONSTANTS ---------------------------------
------------------------------------------------------------------------


------------------------------------------------------------------------
---------------------------- FUNCTIONS ---------------------------------
------------------------------------------------------------------------

    function GetCoordFromPolygon(p : full_polygon_type; v : vertex_num_type; c : integer range 0 to 3) return vec32;
    function GetParamFromPolygon(p : full_polygon_type; v : vertex_num_type; c : integer range 0 to NCOORDS+NVERTEX_ATTR-1) return vec32;

end;

package body gpu_vertex_pkg is

    function GetCoordFromPolygon(p : full_polygon_type; v : vertex_num_type; c : integer range 0 to 3) return vec32 is
    begin
        case c is
            when 0 =>
                return p(v).coord.x;
            when 1 =>
                return p(v).coord.y;
            when 2 =>
                return p(v).coord.z;
            when 3 =>
                return p(v).coord.w;
        end case;
    end function;
    
    -- Returns coords and attributes from polygon by sequential number skipping w coord
    function GetParamFromPolygon(p : full_polygon_type; v : vertex_num_type; c : integer range 0 to NCOORDS+NVERTEX_ATTR-1) return vec32 is
    begin
        case c is
            when 0 =>
                return p(v).coord.x;
            when 1 =>
                return p(v).coord.y;
            when 2 =>
                return p(v).coord.z;
            when others =>
                return p(v).attr(c-3);
        end case;
    end function;

end gpu_vertex_pkg;
