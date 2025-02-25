------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Rasterizer pipeline stage calculating polygon bound rectangle 
-- and iterating pixel center coordinates (x+0.5, y+0.5) in this range.  
-- Uses simplified nonuniversal integer to float conversion routines.
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.std_logic_unsigned.all;

library work;
    use work.gpu_pkg.all;
    use work.rast_pipe_pkg.all;

entity rast_pipe_incr is
    generic (
		SCREEN_WIDTH  : screen_coord_vec := SCREEN_640;
		SCREEN_HEIGHT : screen_coord_vec := SCREEN_480
	);
    port (
        clk_i           : in  std_logic;
		rst_i           : in  std_logic;
        
        next_polygon_i  : in  std_logic;
        next_polygon_o  : out std_logic;
        polygon_ack_o   : out std_logic;
        
        precomp_data_i  : in  precomp_data_out_type;
        precomp_data_o  : out precomp_data_out_type;
        
        incr_to_edge_o  : out incr_to_edge_array;
        edge_to_incr_i  : in  edge_to_incr_array
    );
end rast_pipe_incr;

architecture behav of rast_pipe_incr is

    constant MANTL_SIZE : integer := 4;
    constant MAX_MANTL  : integer := MAX_RESOLUTION_POW;
    
    -- Integer to float exponent
    function IntCoord2Exp(v : screen_coord_vec) return std_logic_vector is
        variable result : std_logic_vector(FLOAT_EXP_WDT-1 downto 0);
    begin
        if v(MAX_MANTL-1 downto 0) = zero_vec(MAX_MANTL) then
            result := to_slv(126, FLOAT_EXP_WDT);
        else
            for i in MAX_MANTL-1 downto 0 loop
                if (v(i) = '1') then
                    result := to_slv(127+i, FLOAT_EXP_WDT);
                    exit;
                end if;
            end loop;
        end if;
        return result;
    end;

    -- Integer to float + 0.5 mantissa
    function IntCoord2Mant(v : screen_coord_vec) return std_logic_vector is
        variable result : std_logic_vector(FLOAT_MANT_WDT-1 downto 0);
        variable bit05  : std_logic;
    begin
        -- add 0.5
        if v = ZERO32 then
            bit05 := '0';
        else
            bit05 := '1';
        end if;
        
        -- mantissa len
        result := zero_vec(FLOAT_MANT_WDT);
        if (v >= 2) then
            for i in MAX_MANTL-1 downto 1 loop
                if (v(i) = '1') then
                    -- construct mantissa from int & 0.5
                    result(FLOAT_MANT_WDT-1 downto FLOAT_MANT_WDT-i-1) := v(i-1 downto 0) & bit05;
                    exit;
                end if;
            end loop;
        else
            result(FLOAT_MANT_WDT-1) := bit05;
        end if;

        return result;
    end;
    
    -- Integer to float + 0.5 (combine)
    function IntCoord2Float(v : screen_coord_vec) return std_logic_vector is
    begin
        return "0" & IntCoord2Exp(v) & IntCoord2Mant(v);  -- non-negative
    end;

    -- Lower bound of rasterization rectangle (lower screen bound is always zero, no need to check)
    function MinBound(x0 : vec32; x1 : vec32; x2 : vec32) return screen_coord_vec is
        variable x0i,x1i,x2i    : screen_coord_vec;
        variable min0           : screen_coord_vec;
        variable result         : screen_coord_vec;
    begin
        x0i := FloatCoord2Int(x0, SCREEN_COORD_WDT);
        x1i := FloatCoord2Int(x1, SCREEN_COORD_WDT);
        x2i := FloatCoord2Int(x2, SCREEN_COORD_WDT);
        if (x0i < x1i) then
            min0 := x0i;
        else
            min0 := x1i;
        end if;
        if (x2i < min0) then
            result := x2i;
        else
            result := min0;
        end if;
        return result;
    end function;
    
    -- Upper bound of rasterization rectangle
    function MaxBound(x0 : vec32; x1 : vec32; x2 : vec32; bound : screen_coord_vec) return screen_coord_vec is
        variable x0i,x1i,x2i    : screen_coord_vec;
        variable max0           : screen_coord_vec;
        variable max1           : screen_coord_vec;
        variable result         : screen_coord_vec;
    begin
        x0i := FloatCoord2Int(x0, SCREEN_COORD_WDT);
        x1i := FloatCoord2Int(x1, SCREEN_COORD_WDT);
        x2i := FloatCoord2Int(x2, SCREEN_COORD_WDT);
        if (x0i > x1i) then
            max0 := x0i;
        else
            max0 := x1i;
        end if;
        if (x2i > max0) then
            max1 := x2i;
        else
            max1 := max0;
        end if;
        if (max1 < bound) then
            result := max1+1;
        else
            result := bound;
        end if;
        return result;
    end function;
    
    type reg_type is record
        bounds          : rect_coord_type;
        x               : screen_coord_array;
        y               : screen_coord_array;
        
        precomp_data    : precomp_data_out_type;
        to_edge         : incr_to_edge_array;
        
        next_polygon    : std_logic;
        polygon_ack     : std_logic;
        busy            : integer range -EDGE_UNITS to EDGE_UNITS;
    end record;
    
    constant r_rst  : reg_type := (
        ZERO_RECT, (others => ZERO_SCREENC), (others => ZERO_SCREENC), 
        ZERO_PRECOMP, (others => ZERO_INCR_TO_EDGE),
        '0', '0', 0
    );
    signal r, rin   : reg_type;
    
begin

EDGE_CONNS : for i in 0 to EDGE_UNITS-1 generate
    incr_to_edge_o(i)  <= (r.to_edge(i).point, r.to_edge(i).point_int, rin.to_edge(i).same_line, rin.to_edge(i).polygon_done);
end generate;

precomp_data_o  <= r.precomp_data;  -- to pass down the pipeline
next_polygon_o  <= r.next_polygon;
polygon_ack_o   <= r.polygon_ack;

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

async_proc : process(all)
    variable v : reg_type;
    
    function AllowNextPoly(e : edge_to_incr_array) return boolean is
    begin
        for i in 0 to EDGE_UNITS-1 loop
            if e(i).no_next_poly then
                return False;
            end if;
        end loop;
        return True;
    end function;
    
    constant EU_MASK    : std_logic_vector(SCREEN_COORD_WDT-1 downto 0) := zero_vec(SCREEN_COORD_WDT-EDGE_UNITS_POW) & max_vec(EDGE_UNITS_POW);
begin
    v := r;
    
    v.next_polygon := '0';
    v.polygon_ack  := '0';

    for i in 0 to EDGE_UNITS-1 loop
        v.to_edge(i).polygon_done := '0';
        
        if edge_to_incr_i(i).done_ack then
            v.busy := v.busy - 1;
        end if;
    end loop;
    
    -- Get new polygon
    if (v.busy = 0) and (next_polygon_i = '1') and AllowNextPoly(edge_to_incr_i) then
        -- calc bounds
        v.bounds.x_min := MinBound(precomp_data_i.polygon(0).coord.x, precomp_data_i.polygon(1).coord.x, precomp_data_i.polygon(2).coord.x);
        v.bounds.y_min := MinBound(precomp_data_i.polygon(0).coord.y, precomp_data_i.polygon(1).coord.y, precomp_data_i.polygon(2).coord.y);
        v.bounds.x_max := MaxBound(precomp_data_i.polygon(0).coord.x, precomp_data_i.polygon(1).coord.x, precomp_data_i.polygon(2).coord.x, SCREEN_WIDTH-1);
        v.bounds.y_max := MaxBound(precomp_data_i.polygon(0).coord.y, precomp_data_i.polygon(1).coord.y, precomp_data_i.polygon(2).coord.y, SCREEN_HEIGHT-1);
        
        v.polygon_ack := '1';
        
        -- check if out of screen
        if  (v.bounds.x_min < SCREEN_WIDTH) and 
            (v.bounds.y_min < SCREEN_HEIGHT) and 
            (v.bounds.x_max /= ZERO_SCREENC) and 
            (v.bounds.y_max /= ZERO_SCREENC)
        then
            -- polygon is on screen - process it
            v.precomp_data := precomp_data_i;
            
            v.next_polygon := '1';  
            v.busy := EDGE_UNITS;  
            for i in 0 to EDGE_UNITS-1 loop
                v.to_edge(i).same_line := '0';
                v.x(i) := v.bounds.x_min;
                -- each edge unit takes Y lines with its number in last bits
                -- for example in case of 4, 0th always gets lines 0,4,8,etc
                v.y(to_uint((to_slv(i,SCREEN_COORD_WDT)+(v.bounds.y_min and EU_MASK)) and EU_MASK)) := v.bounds.y_min+i;
            end loop;
        end if;
    else
        for i in 0 to EDGE_UNITS-1 loop
            if edge_to_incr_i(i).next_coord = '1' then
                -- iterate in polygon bounds
                if (r.x(i) = r.bounds.x_max) or (edge_to_incr_i(i).line_done = '1') then
                    if (r.y(i) + EDGE_UNITS > r.bounds.y_max) then
                        v.to_edge(i).polygon_done := '1';
                    else
                        v.x(i) := r.bounds.x_min;
                        v.y(i) := r.y(i) + EDGE_UNITS;
                        v.to_edge(i).same_line := '0';
                    end if;
                else
                    v.x(i) := r.x(i) + 1;
                    v.to_edge(i).same_line := '1';
                end if;
            end if;
        end loop;
    end if;
    
    -- calc point center coords 
    for i in 0 to EDGE_UNITS-1 loop
        v.to_edge(i).point.x := IntCoord2Float(v.x(i));
        v.to_edge(i).point.y := IntCoord2Float(v.y(i));
        
        v.to_edge(i).point_int := (r.x(i), r.y(i));
    end loop;
    
    rin <= v;
end process;

end behav;
