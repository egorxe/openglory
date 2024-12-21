------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Rasterizer pipeline wrapper for AXI-Stream
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.std_logic_unsigned.all;

    use work.gpu_pkg.all;
    use work.rast_pipe_pkg.all;
    
    use std.env.all;

entity rast_pipe_axis_wrapper is
    generic (
        VERBOSE         : boolean := False
    );
    port (
        clk_i           : in  std_logic;
		rst_i           : in  std_logic;
        
        s_axis_tdata    : in  std_logic_vector(GLOBAL_AXIS_DATA_WIDTH - 1 downto 0);
        s_axis_tkeep    : in  std_logic_vector(3 downto 0);
        s_axis_tvalid   : in  std_logic;
        s_axis_tlast    : in  std_logic;
        s_axis_tid      : in  std_logic_vector(3 downto 0);
        s_axis_tdest    : in  std_logic_vector(3 downto 0);
        s_axis_tuser    : in  std_logic_vector(3 downto 0);
        s_axis_tready   : out std_logic;
        
        m_axis_tdata    : out std_logic_vector(GLOBAL_AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tkeep    : out std_logic_vector(3 downto 0);
        m_axis_tvalid   : out std_logic;
        m_axis_tlast    : out std_logic;
        m_axis_tid      : out std_logic_vector(3 downto 0);
        m_axis_tdest    : out std_logic_vector(3 downto 0);
        m_axis_tuser    : out std_logic_vector(3 downto 0);
        m_axis_tready   : in  std_logic;
        
        debug_o         : out vec32
    );
end rast_pipe_axis_wrapper;

architecture behav of rast_pipe_axis_wrapper is
    
    type rcv_state_type is (RCV_IDLE, RCV_PASS_CMD, RCV_UPDATE_STATE_0, RCV_UPDATE_STATE, RCV_VERTICES_0, RCV_VERTICES, RCV_WAIT_RASTERIZER, RCV_AXIS_SEND);
    type send_state_type is (SEND_IDLE, SEND_XY, SEND_Z, SEND_ARGB, SEND_TX, SEND_TY, SEND_FINISH);

    type reg_type is record
        rcv_state       : rcv_state_type;
        next_rcv_state  : rcv_state_type;
        send_state      : send_state_type;
            
        rcv_ready       : std_logic;
        send_valid      : std_logic;
        send_valid_frag : std_logic;
        send_last       : std_logic;
        send_data       : std_logic_vector(GLOBAL_AXIS_DATA_WIDTH-1 downto 0);
            
        culling         : std_logic_vector(GPU_STATE_RAST_CULL_HI-GPU_STATE_RAST_CULL_LO downto 0);
        attr_num        : attrib_num_type;
        cmd_error       : std_logic;
        
        polygon         : full_polygon_type;
        next_polygon    : std_logic;
        done_ack        : std_logic;
        sending_fragment: fragment_full_type;
        
        fifo_pop        : std_logic;
        
        comp_cnt        : integer range 0 to NVERTEX_ATTR+NWCOORDS-1;
        rcv_vertex_cnt  : vertex_num_type;
        rcv_pass_cnt    : integer range 0 to 255;
        rcv_pass_size   : integer range 0 to 255;
    end record;
    
    constant r_rst  : reg_type := (
        RCV_IDLE, RCV_IDLE, SEND_IDLE,
        '0', '0', '0', '0', ZERO32, 
        "11", 3, '0', 
        ZERO_FULL_POLYGON, '0', '0', ZERO_FFRAGMENT, 
        '0', 
        0, 0, 0, 0
    );
    signal r, rin   : reg_type;
    
    signal frag_ready       : std_logic;
    signal polygon_ack      : std_logic;
    signal rast_busy        : std_logic;
    signal rast_pipe_busy   : std_logic;
    signal fragment         : fragment_full_type;
    
    signal debug            : vec32;
    
    procedure verbose_print(str : string) is
    begin
        if VERBOSE then
            report str;
        end if;
    end;

begin

-- Master AXI-stream
m_axis_tkeep    <= (others => '1');
m_axis_tid      <= (others => '0');
m_axis_tdest    <= (others => '0');
m_axis_tuser    <= (others => '0');
m_axis_tlast    <= r.send_last; 
m_axis_tdata    <= r.send_data;
m_axis_tvalid   <= r.send_valid or r.send_valid_frag;
assert((r.send_valid and r.send_valid_frag) /= '1') severity failure;

-- Slave AXI-stream
s_axis_tready   <= r.rcv_ready;

debug_o(15 downto 0)  <= debug(15 downto 0);
debug_o(19 downto 16) <= to_slv(rcv_state_type'pos(r.rcv_state), 4);
debug_o(20) <= r.cmd_error;
debug_o(31 downto 21) <= (others => '0');

rast_busy <= rast_pipe_busy or r.next_polygon /*or (not fifo_empty)*/ or to_sl(rin.send_state /= SEND_IDLE);

rasterizer : entity work.rast_pipe
    port map (
        clk_i               => clk_i,
		rst_i               => rst_i,
            
        polygon_i           => r.polygon,
        next_polygon_i      => r.next_polygon,
        polygon_ack_o       => polygon_ack,
            
        culling_i           => r.culling,
        attr_num_i          => r.attr_num,
            
        --stall_i             => fifo_afull,
        busy_o              => rast_pipe_busy,
        frag_ready_o        => frag_ready,
        fragment_o          => fragment,
        frag_pop_i          => r.fifo_pop,
        
        debug_o             => debug
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

async_proc : process(all)
    variable v : reg_type;
begin
    v := r;
    
    v.send_last := '0';
    v.fifo_pop  := '0';
    
    case r.rcv_state is
            
        when RCV_IDLE =>
            -- Wait for command on AXIS & check it without ready
            if (s_axis_tvalid = '1') then
                case s_axis_tdata is
                    when GPU_PIPE_CMD_POLY_VERTEX4 =>
                        -- switch to polygons with other attribute count only with empty rasterizer
                        if (rast_busy = '0') or (r.attr_num = 3) then
                            verbose_print("Start of polygon processing");
                            v.rcv_state := RCV_VERTICES_0;
                            v.rcv_vertex_cnt := 0;
                            v.comp_cnt := 0;
                            v.rcv_ready := '1';
                            v.attr_num := 3;
                        end if;
                        
                    when GPU_PIPE_CMD_POLY_VERTEX4TC =>
                        -- !! switch to polygons with other attribute count only with empty rasterizer !!
                        if (rast_busy = '0') or (r.attr_num = 1) then
                            verbose_print("Start of textured polygon processing");
                            v.rcv_state := RCV_VERTICES_0;
                            v.rcv_vertex_cnt := 0;
                            v.comp_cnt := 0;
                            v.rcv_ready := '1';
                            v.attr_num := 5;
                        end if;
                        
                    when GPU_PIPE_CMD_RAST_STATE =>
                        verbose_print("Got rcv_state update");
                        -- wait till rasterizer is free to update value
                        if rast_busy = '0' then
                            v.rcv_state := RCV_UPDATE_STATE_0;
                            v.rcv_ready := '1';
                        end if;

                    when others =>
                        -- wait till rasterizer is free to keep command order
                        if rast_busy = '0' then
                            v.rcv_ready := '1';
                            v.rcv_state := RCV_PASS_CMD;
                            v.rcv_pass_size := cmd_num_args(s_axis_tdata);
                            v.rcv_pass_cnt := 0;
                        end if;
                end case;
            end if;
        
        when RCV_UPDATE_STATE_0 =>
            v.rcv_state := RCV_UPDATE_STATE;
        
        when RCV_UPDATE_STATE =>
            if (s_axis_tvalid = '1') then
                v.rcv_ready := '0';
                v.culling := s_axis_tdata(GPU_STATE_RAST_CULL_HI downto GPU_STATE_RAST_CULL_LO);
                v.rcv_state := RCV_IDLE;
            end if;
        
         when RCV_PASS_CMD =>
            v.rcv_ready := '1';
            if (s_axis_tvalid = '1') then
                v.rcv_ready := '0';
                v.send_data := s_axis_tdata;
                v.send_valid := '1';
                v.rcv_state := RCV_AXIS_SEND;
                if r.rcv_pass_cnt = r.rcv_pass_size then
                    v.next_rcv_state := RCV_IDLE;
                    v.send_last := '1';
                else
                    v.next_rcv_state := RCV_PASS_CMD;
                    v.rcv_pass_cnt := r.rcv_pass_cnt + 1;
                end if;
            end if;
            
        when RCV_VERTICES_0 =>
            v.rcv_state := RCV_VERTICES;
            
        when RCV_VERTICES =>
            v.rcv_ready := '1';
            -- read 3x8 floats representing vertexes
            if s_axis_tvalid = '1' then
                case r.comp_cnt is
                    when 0 =>
                        v.polygon(r.rcv_vertex_cnt).coord.x := s_axis_tdata;
                    when 1 =>
                        v.polygon(r.rcv_vertex_cnt).coord.y := s_axis_tdata;
                    when 2 =>
                        v.polygon(r.rcv_vertex_cnt).coord.z := s_axis_tdata;
                    when 3 =>
                        v.polygon(r.rcv_vertex_cnt).coord.w := s_axis_tdata;
                    --when others =>
                        --v.polygon(r.rcv_vertex_cnt).attr(r.comp_cnt-4) := s_axis_tdata;
                    when 4 =>
                        v.polygon(r.rcv_vertex_cnt).attr(0) := s_axis_tdata;
                    when 5 =>
                        v.polygon(r.rcv_vertex_cnt).attr(1) := s_axis_tdata;
                    when 6 =>
                        v.polygon(r.rcv_vertex_cnt).attr(2) := s_axis_tdata;
                    when 7 =>
                        v.polygon(r.rcv_vertex_cnt).attr(3) := s_axis_tdata;
                    when 8 =>
                        -- !! add attr offset instead of moving texcoords to front !!
                        v.polygon(r.rcv_vertex_cnt).attr(0) := s_axis_tdata;
                    when 9 =>
                        -- !! add attr offset instead of moving texcoords to front !!
                        v.polygon(r.rcv_vertex_cnt).attr(1) := s_axis_tdata;
                end case;
                
                if r.comp_cnt = 4+r.attr_num then
                    v.comp_cnt := 0;

                    if v.rcv_vertex_cnt = 2 then
                        if r.attr_num = 5 then
                            -- ! calc only texcoords !
                            v.attr_num := 1;
                        end if;
                        -- launch rasterizer
                        v.rcv_state := RCV_WAIT_RASTERIZER;
                        v.rcv_ready := '0';
                        v.next_polygon := '1';
                    else
                        v.rcv_vertex_cnt := r.rcv_vertex_cnt + 1;
                    end if;
                else
                    v.comp_cnt := r.comp_cnt + 1;
                end if;
            end if;
            
        when RCV_WAIT_RASTERIZER =>
            if polygon_ack then
                v.next_polygon := '0';
                v.rcv_state := RCV_IDLE;
            end if;
            
        when RCV_AXIS_SEND =>
            if (m_axis_tready = '1') then
                v.send_valid := '0';
                v.send_last := '0';
                v.rcv_state := r.next_rcv_state;
                if r.next_rcv_state = RCV_PASS_CMD then
                    v.rcv_ready := '1';
                end if;
            end if;
            
    end case;
    
    -- FSM to pass data from processed fragments FIFO to stream output FIFO
    case (r.send_state) is
        when SEND_IDLE =>
            v.send_valid_frag := '0';
            if frag_ready then
                v.sending_fragment := fragment; --Vec2Fragment(fifo_out);
                v.fifo_pop := '1';
                v.send_valid_frag := '1';
                if r.attr_num = 3 then  
                    v.send_data := GPU_PIPE_CMD_FRAGMENT;
                else
                    v.send_data := GPU_PIPE_CMD_TEXFRAGMENT;
                end if;
                v.send_state := SEND_XY;
            end if;
            
        when SEND_XY =>
            if (m_axis_tready = '1') then
                v.send_data := extl_vec(r.sending_fragment.y, 16) & extl_vec(r.sending_fragment.x, 16);
                v.send_state := SEND_Z;
            end if;
            
        when SEND_Z =>
            if (m_axis_tready = '1') then
                v.send_data := extl_vec(r.sending_fragment.z, 32);
                if r.attr_num = 3 then
                    v.send_state := SEND_ARGB;
                else
                    v.send_state := SEND_TX;
                end if;
            end if;
            
        when SEND_ARGB =>
            v.send_last := '1';
            if (m_axis_tready = '1') then
                v.send_data := r.sending_fragment.argb;
                v.send_state := SEND_FINISH;
            end if;
                    
        when SEND_TX =>
            if (m_axis_tready = '1') then
                v.send_data := r.sending_fragment.tx;    
                v.send_state := SEND_TY;
            end if;
                    
        when SEND_TY =>
            v.send_last := '1';
            if (m_axis_tready = '1') then
                v.send_data := r.sending_fragment.ty;    
                v.send_state := SEND_FINISH;
            end if;
            
        when SEND_FINISH =>
            v.send_valid_frag := '1';
            v.send_last := '1';
            if (m_axis_tready = '1') then
                if frag_ready then
                    v.sending_fragment := fragment; 
                    v.fifo_pop := '1';
                    v.send_valid_frag := '1';
                    if r.attr_num = 3 then
                        v.send_data := GPU_PIPE_CMD_FRAGMENT;
                    else
                        v.send_data := GPU_PIPE_CMD_TEXFRAGMENT;
                    end if;
                    v.send_state := SEND_XY;
                else
                    v.send_valid_frag := '0';
                    v.send_last := '0';
                    v.send_state := SEND_IDLE;
                end if;
            end if;
            
    end case;
    
    rin <= v;
end process;

end behav;
