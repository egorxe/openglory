------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Rasterizer pipeline stage calculating 3 edge functions
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.float_pkg.all;

library work;
    use work.gpu_pkg.all;
    use work.rast_pipe_pkg.all;

entity rast_pipe_edge is
    port (
        clk_i           : in  std_logic;
		rst_i           : in  std_logic;
        
        bary_busy_i     : in  std_logic_vector(BARY_UNITS_PER_EDGE-1 downto 0);
        next_polygon_i  : in  std_logic;
        precomp_data_i  : in  precomp_data_out_type;
        stall_i         : in  std_logic;

        incr_to_edge_i  : in  incr_to_edge_type;
        edge_to_incr_o  : out edge_to_incr_type;
        
        busy_o          : out std_logic;
        pipe_edge_o     : out edge_to_bary_array
    );
end rast_pipe_edge;

architecture behav of rast_pipe_edge is
    
    constant EXP_LIMIT  : integer := 118;   -- exponent less than this is considered zero for edge func result ~0.00195
    constant BU         : integer := BARY_UNITS_PER_EDGE;   -- shorter

    subtype pipe_edge_out_vec is std_logic_vector(edge_func_out_array'length*32 + SCREEN_COORD_WDT*2 downto 0);
    type pipe_edge_out_array is array (0 to BU-1) of pipe_edge_out_vec;
    type EdgeFuncVertexArray is array (0 to EDGE_FUNC_CNT-1) of point_coord_type;
    subtype bary_cnt_type is integer range 0 to BU-1;
   
    type state_type is (IDLE, NEXT_COORD, EDGE_WAIT);

    type reg_type is record
        state               : state_type;
        point               : point_coord_type;
        point_int           : screen_point_type;
                
        cached              : std_logic_vector(1 downto 0);
        next_coord          : std_logic;
        ef_valid            : std_logic;
        new_polygon_cnt     : integer range 0 to BU;
        new_polygon_in_fifo : integer range -1 to BU;
        polygon_done        : std_logic;
        done_ack            : std_logic;
        
        line_done           : std_logic;
        prev_match          : std_logic;
        
        fifo_push           : std_logic_vector(BU-1 downto 0);
        fifo_pop            : std_logic_vector(BU-1 downto 0);
        fifo_in             : pipe_edge_out_vec;
        
        cur_bary_push       : bary_cnt_type;
        cur_bary_pop        : bary_cnt_type;
    end record;
    
    constant r_rst      : reg_type := (
        IDLE, ZERO_POINT_COORD, ZERO_SPOINT, 
        "00", '0', '0', 0, 0, '0', '0',
        '0', '0',
        (others => '0'), (others => '0'), (others => '0'),
        0, 0
    );
    
    signal ef_busy      : std_logic_vector(EDGE_FUNC_CNT-1 downto 0);
    signal ef_ready     : std_logic_vector(EDGE_FUNC_CNT-1 downto 0);
    signal ef_v0        : EdgeFuncVertexArray;
    signal ef_v1        : EdgeFuncVertexArray;
    signal edge_func_res: edge_func_out_array;
    
    signal fifo_out     : pipe_edge_out_array;
    signal fifo_empty   : std_logic_vector(BU-1 downto 0);
    signal fifo_afull   : std_logic_vector(BU-1 downto 0);
    
    signal r, rin       : reg_type;
    
    constant FIFO_NEW_POLYGON_BIT   : integer := 0;
    
    function ToPipeEdgeOutVec(ef : edge_func_out_array; p : screen_point_type; new_polygon : std_logic) return pipe_edge_out_vec is
    variable result : pipe_edge_out_vec;
    begin
        result(FIFO_NEW_POLYGON_BIT) := new_polygon;
        for i in 0 to EDGE_FUNC_CNT-1 loop
            result((i+1)*32 downto i*32+1) := ef(i);
        end loop;
        result(result'high downto result'high-SCREEN_COORD_WDT+1) := p.x;
        result(result'high-SCREEN_COORD_WDT downto result'high-SCREEN_COORD_WDT*2+1) := p.y;
        return result;
    end;
    
    function FromPipeEdgeOutVec(v : in pipe_edge_out_vec) return pipe_edge_out_type is
        variable o : pipe_edge_out_type;
    begin
        o.new_polygon := v(FIFO_NEW_POLYGON_BIT);
        for i in 0 to EDGE_FUNC_CNT-1 loop
            o.ef(i) := v((i+1)*32 downto i*32+1);
        end loop;
        o.p.x := v(v'high downto v'high-SCREEN_COORD_WDT+1);
        o.p.y := v(v'high-SCREEN_COORD_WDT downto v'high-SCREEN_COORD_WDT*2+1);
        return o;
    end;
    
    function edge_match(edge : vec32; frontface : std_logic) return boolean is
    begin
        return (float_exp(edge) < EXP_LIMIT) or (edge(FLOAT_SIGN) = frontface);
    end function;

begin

-- Generate edge functions
ef_gen : for i in 0 to EDGE_FUNC_CNT-1 generate
begin
    efs : entity work.rast_edge_mac
    port map (
        clk_i       => clk_i,
        rst_i       => rst_i,
    
        valid_i     => r.ef_valid,
        cached_i    => r.cached,
        ready_o     => ef_ready(i),
        busy_o      => ef_busy(i),
    
        x_i         => incr_to_edge_i.point.x,
        y_i         => incr_to_edge_i.point.y,
        v0x_i       => ef_v0(i).x,
        v0y_i       => ef_v0(i).y,
        v1x_i       => ef_v1(i).x,
        v1y_i       => ef_v1(i).y,
    
        result_o    => edge_func_res(i)
    );		
end generate;

-- FIFOs for output data
FIFOS_GEN : for i in 0 to BARY_UNITS_PER_EDGE-1 generate
    output_fifo : entity work.afull_fifo
        generic map (
            ALLOW_FULL_EMPTY    => False,
            DEPTH               => 4,  
            WDT                 => pipe_edge_out_vec'length
        )
        port map (
            clk_i   => clk_i,
            rst_i   => rst_i,
            dat_i   => r.fifo_in,
            dat_o   => fifo_out(i),
            push_i  => r.fifo_push(i), 
            pop_i   => r.fifo_pop(i),
            afull_o => fifo_afull(i),
            empty_o => fifo_empty(i)
        );
end generate;


-- Connect edge functions inputs
ef_v0(0)        <= Wcoord2Coord(precomp_data_i.polygon(1).coord);
ef_v1(0)        <= Wcoord2Coord(precomp_data_i.polygon(2).coord);
ef_v0(1)        <= Wcoord2Coord(precomp_data_i.polygon(2).coord);
ef_v1(1)        <= Wcoord2Coord(precomp_data_i.polygon(0).coord);
ef_v0(2)        <= Wcoord2Coord(precomp_data_i.polygon(0).coord);
ef_v1(2)        <= Wcoord2Coord(precomp_data_i.polygon(1).coord);

-- Connect outputs
edge_to_incr_o.next_coord   <= r.next_coord;
edge_to_incr_o.done_ack     <= r.done_ack;
edge_to_incr_o.line_done    <= r.line_done;
edge_to_incr_o.no_next_poly <= to_sl(r.new_polygon_in_fifo /= 0);

busy_o <= ef_busy(0) or ef_ready(0) or or_all(r.fifo_push) or or_all(not fifo_empty) or to_sl(r.state /= IDLE);

BARY_CONN : for i in 0 to BARY_UNITS_PER_EDGE-1 generate
    pipe_edge_o(i).edge        <= FromPipeEdgeOutVec(fifo_out(i));
    pipe_edge_o(i).edge_done   <= r.fifo_pop(i);
end generate;

seq_proc : process(clk_i)
begin
    if Rising_edge(clk_i) then
        if rst_i = '1' then
            r <= r_rst;
        else
            r <= rin;
            assert r.new_polygon_in_fifo >= 0 severity failure;
        end if;
    end if;
end process;

async_proc : process(all)
    variable v : reg_type;
    
    function IncBaryCnt(i : bary_cnt_type) return bary_cnt_type is
    begin
        if i = BU-1 then
            return 0;
        else
            return i + 1;
        end if;
    end function;
begin
    v := r;
    
    v.ef_valid      := '0';
    v.next_coord    := '0';
    v.done_ack      := '0';
    v.fifo_push     := (others => '0');
    v.fifo_pop      := (others => '0');
    
    if (bary_busy_i(r.cur_bary_pop) = '0') and (fifo_empty(r.cur_bary_pop) = '0') and (stall_i = '0') then
        v.fifo_pop(r.cur_bary_pop) := '1';
        if fifo_out(r.cur_bary_pop)(FIFO_NEW_POLYGON_BIT) = '1' then
            v.new_polygon_in_fifo := r.new_polygon_in_fifo - 1;
        end if;
        -- Inc fifo pop counter
        v.cur_bary_pop := IncBaryCnt(r.cur_bary_pop);
    end if;
    
    if not incr_to_edge_i.same_line then
        v.line_done := '0';
        v.prev_match := '0';
    end if;
    
    -- check function result
    if ef_ready(0) = '1' then
        -- check edge function result, 'backface' is a sign digit of area
        if  edge_match(edge_func_res(0), precomp_data_i.area_recip(FLOAT_SIGN)) and
            edge_match(edge_func_res(1), precomp_data_i.area_recip(FLOAT_SIGN)) and
            edge_match(edge_func_res(2), precomp_data_i.area_recip(FLOAT_SIGN)) 
        then
            v.fifo_push(r.cur_bary_push) := '1';
            v.fifo_in := ToPipeEdgeOutVec(edge_func_res, r.point_int, to_sl(r.new_polygon_cnt /= 0));
            if r.new_polygon_cnt /= 0 then
                v.new_polygon_cnt := r.new_polygon_cnt - 1;
                v.new_polygon_in_fifo := v.new_polygon_in_fifo + 1;
            end if;
            v.cur_bary_push := IncBaryCnt(r.cur_bary_push);
            v.prev_match := '1';
        elsif v.prev_match then
            -- no need to calculate this line further as we've "exited" out of triangle
            v.line_done := '1';
        end if;
    end if;
    
    if incr_to_edge_i.polygon_done then
        v.polygon_done := '1';
    end if;
    
    case r.state is
        -- Wait for next polygon
        when IDLE =>
            if next_polygon_i = '1' then
                v.cached    := "00";
                v.state     := NEXT_COORD;
                v.new_polygon_cnt := BU;
            end if;
        
        -- Request next coord if not FIFO full
        when NEXT_COORD =>
            if fifo_afull(r.cur_bary_push) = '0' then
                v.next_coord := not v.polygon_done;
                v.state     := EDGE_WAIT;
                v.ef_valid  := '1';
                
                v.point     := incr_to_edge_i.point;
                v.point_int := incr_to_edge_i.point_int;
            end if;
            
        -- Wait for edge function calc to complete
        when EDGE_WAIT =>
            -- no need to recalculate vertex edge components
            v.cached    := incr_to_edge_i.same_line & '1';
            
            -- set next req in advance
            if (fifo_afull(IncBaryCnt(r.cur_bary_push)) = '0') and (v.polygon_done = '0') then
                v.ef_valid  := '1';
            end if;
            
            if ef_ready(0) = '1' then
                if v.polygon_done then
                    v.polygon_done := '0';
                    v.done_ack     := '1';
                    v.state := IDLE;
                else
                    v.state := NEXT_COORD;
                end if;
            end if;
            
    end case;

    rin <= v;
end process;

end behav;
