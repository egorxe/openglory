------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Fragment operations stage
--
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.fixed_pkg.all;

use work.rast_pipe_pkg.all;
use work.gpu_pkg.all;

entity fragment_axis is
    generic (
        SCREEN_WIDTH    : integer := 640;
        SCREEN_HEIGHT   : integer := 480;
        FAST_CLEAR      : boolean := False;
        ZBUF_BASE_ADDR  : vec32
    );
    port (
            clk_i       : in  std_logic;
            rst_i       : in  std_logic;

            axis_mosi_i : in  global_axis_mosi_type;
            axis_miso_o : out global_axis_miso_type;

            axis_mosi_o : out global_axis_mosi_type;
            axis_miso_i : in  global_axis_miso_type;
            
            frag_wb_o   : out wishbone_mosi_type;
            frag_wb_i   : in  wishbone_miso_type;
            
            fb_addr_i   : vec32;
            fb_wb_o     : out wishbone_mosi_type;
            fb_wb_i     : in  wishbone_miso_type;
            
            cache_inv_o : out std_logic_vector(1 downto 0)
        );
end fragment_axis;

architecture behavioral of fragment_axis is

    constant STATE_FRAG_DEPTH_BIT       : integer := 0;
    constant STATE_FRAG_DEPTHMASK_BIT   : integer := 1;
    constant STATE_FRAG_ALPHA_BIT       : integer := 2;
    constant STATE_FRAG_BLEND_BIT       : integer := 3;
    
    constant STATE_FRAG_BLEND_FUNC_WDT  : integer := 4;
    constant STATE_FRAG_BLEND_SFUNC_LO  : integer := 12;
    constant STATE_FRAG_BLEND_SFUNC_HI  : integer := STATE_FRAG_BLEND_SFUNC_LO+STATE_FRAG_BLEND_FUNC_WDT-1;
    constant STATE_FRAG_BLEND_DFUNC_LO  : integer := STATE_FRAG_BLEND_SFUNC_HI+1;
    constant STATE_FRAG_BLEND_DFUNC_HI  : integer := STATE_FRAG_BLEND_DFUNC_LO+STATE_FRAG_BLEND_FUNC_WDT-1;
    
    constant FB_OFFSET_WDT              : integer := SCREEN_COORD_WDT*2;
    constant FB_SIZE                    : integer := SCREEN_WIDTH*SCREEN_HEIGHT;
    
    constant COLOR_BITS                 : integer := 8;
    
    type blend_func_enum is (
        BLENDF_ZERO,
        BLENDF_ONE,
        BLENDF_SRC_COLOR,
        BLENDF_ONE_MINUS_SRC_COLOR,
        BLENDF_DST_COLOR,
        BLENDF_ONE_MINUS_DST_COLOR,
        BLENDF_SRC_ALPHA,
        BLENDF_ONE_MINUS_SRC_ALPHA,
        BLENDF_DST_ALPHA,
        BLENDF_ONE_MINUS_DST_ALPHA,
        BLENDF_SRC_ALPHA_SATURATE
    );
    
    type fb_fragment_type is record
        fb_addr : std_logic_vector(FB_OFFSET_WDT-1 downto 0);
        argb    : vec32;
    end record;
    subtype fb_fragment_vec is std_logic_vector(FB_OFFSET_WDT+32-1 downto 0);
    constant ZERO_FB_FRAGMENT : fb_fragment_type := ((others => '0'), ZERO32);
    
    subtype blend_func_type is std_logic_vector(STATE_FRAG_BLEND_FUNC_WDT-1 downto 0);
    constant ZERO_BLEND_FUNC : blend_func_type := zero_vec(STATE_FRAG_BLEND_FUNC_WDT);
    
    subtype fixed_color_type is ufixed(-1 downto -COLOR_BITS);
    subtype fixed_res_type is ufixed(0 downto -COLOR_BITS);
    type blend_color_array is array (0 to NCOLORS-1) of fixed_color_type;
    type blend_result_array is array (0 to NCOLORS-1) of fixed_res_type;
    constant ZERO_BLEND_ARRAY : blend_color_array := (others => (others => '0'));
    
    function FbFragment2Vec(f : fb_fragment_type) return fb_fragment_vec is
    begin
        return f.argb & f.fb_addr;
    end function;
    
    function Vec2FbFragment(v : fb_fragment_vec) return fb_fragment_type is
        variable f : fb_fragment_type;
    begin
        f.fb_addr := v(FB_OFFSET_WDT-1 downto 0);
        f.argb := v(FB_OFFSET_WDT+31 downto FB_OFFSET_WDT);
        return f;
    end function;
    
    function BlendFactor(f : blend_func_type; src : blend_color_array; i : integer range 0 to NCOLORS-1) return fixed_color_type is
        variable fact : fixed_color_type;
    begin
        case (blend_func_enum'val(to_uint(f))) is
            when BLENDF_ZERO =>
                fact := to_ufixed(zero_vec(COLOR_BITS), -1, -COLOR_BITS);
                
            when BLENDF_ONE =>
                fact := to_ufixed(max_vec(COLOR_BITS), -1, -COLOR_BITS);
                
            when BLENDF_ONE_MINUS_SRC_COLOR =>
                fact := resize(to_ufixed(max_vec(COLOR_BITS), -1, -COLOR_BITS) - src(i), fact);
                
            when BLENDF_SRC_ALPHA =>
                fact := src(3);
                
            when BLENDF_ONE_MINUS_SRC_ALPHA =>
                fact := resize(to_ufixed(max_vec(COLOR_BITS), -1, -COLOR_BITS) - src(3), fact);
                
            when others =>
                assert False report "Unsupported blending function!" severity failure;
                fact := to_ufixed(zero_vec(COLOR_BITS), -1, -COLOR_BITS);
        end case;
        
        return fact;
    end function;
    
    function Argb2Fixed(v : vec32) return blend_color_array is
        variable res : blend_color_array;
    begin
        for i in 0 to NCOLORS-1 loop
            res(i) := to_ufixed(v((i+1)*8 - 1 downto i*8), -1, -COLOR_BITS);
        end loop;
        return res;
    end;
    
    function Fixed2Argb(v : blend_result_array) return vec32 is
        variable tmp : std_logic_vector(8 downto 0);
        variable res : vec32;
    begin
        for i in 0 to NCOLORS-1 loop
            if v(i)(0) = '0' then
                tmp := to_slv(v(i));
                res((i+1)*8 - 1 downto i*8) := tmp(7 downto 0);
            else
                res((i+1)*8 - 1 downto i*8) := max_vec(8);
            end if;
        end loop;
        return res;
    end;

    type rcv_state_type is (RCV_READY, RCV_IDLE, RCV_FRAG_CMD, RCV_FRAGSTATE_0, RCV_FRAGSTATE_1, RCV_PASS_CMD, RCV_XY, RCV_Z, RCV_ARGB, RCV_AXIS_SEND);
    type frag_state_type is (FRAG_IDLE, FRAG_ALPHA_CHECK, FRAG_ZBUF_READ, FRAG_ZBUF_TEST, FRAG_ZBUF_CLEAR, FRAG_DONE);
    type fb_state_type is (FB_IDLE, FB_CLEAR, FB_BLEND0, FB_BLEND1);

    type reg_type is record
        rcv_state           : rcv_state_type;
        next_rcv_state      : rcv_state_type;
        frag_state          : frag_state_type;
        fb_state            : fb_state_type;
            
        rcv_ready           : std_logic;
        send_valid          : std_logic;
        send_last           : std_logic;
        send_data           : std_logic_vector(GLOBAL_AXIS_DATA_WIDTH-1 downto 0);
        
        rcv_pass_cnt        : integer range 0 to 255;
        rcv_pass_size       : integer range 0 to 255;
        
        clear_fb            : std_logic;
        clear_zb            : std_logic;
        
        fb_off              : std_logic_vector(FB_OFFSET_WDT-1 downto 0);
        
        frag_fifo_push      : std_logic;
        frag_fifo_pop       : std_logic;
        fb_fifo_push        : std_logic;
        fb_fifo_pop         : std_logic;
        
        fragment            : fragment_type;
        proc_fragment       : fragment_type;
        fb_fragment         : fb_fragment_type;
        
        depth_test_enabled  : std_logic;
        depth_upd_enabled   : std_logic;
        alpha_test_enabled  : std_logic;
        blending_enabled    : std_logic;
        blend_sfunc         : blend_func_type;
        blend_dfunc         : blend_func_type;
        
        blend_array         : blend_color_array;
        src_blend           : blend_color_array;
        dst_blend           : vec32;
        
        frag_wb_stb         : std_logic;
        frag_wb_we          : std_logic;
        frag_wb_adr         : vec32;
        frag_wb_dato        : vec32;
        
        fb_wb_stb           : std_logic;
        fb_wb_we            : std_logic;
        fb_wb_adr           : vec32;
        fb_wb_dato          : vec32;
    end record;
    
    constant r_rst  : reg_type := (
        RCV_READY, RCV_READY, FRAG_IDLE, FB_IDLE,
        '0', '0', '0', ZERO32,
        0, 0,
        '0', '0',
        (others => '0'),
        '0', '0', '0', '0',
        ZERO_FRAGMENT, ZERO_FRAGMENT, ZERO_FB_FRAGMENT,
        '0', '0', '0', '0', ZERO_BLEND_FUNC, ZERO_BLEND_FUNC,
        ZERO_BLEND_ARRAY, ZERO_BLEND_ARRAY, ZERO32,
        '0', '0', ZERO32, ZERO32,
        '0', '0', ZERO32, ZERO32
    );
    signal r, rin   : reg_type;
    
    signal frag_busy            : std_logic;
    
    signal frag_fifo_out        : fragment_vec;
    signal frag_fifo_full       : std_logic;
    signal frag_fifo_empty      : std_logic;
    signal fb_fifo_out          : fb_fragment_vec;
    signal fb_fifo_full         : std_logic;
    signal fb_fifo_empty        : std_logic;

begin

-- Stream connections
axis_mosi_o.axis_tvalid <= r.send_valid;
axis_mosi_o.axis_tlast  <= r.send_last;
axis_mosi_o.axis_tdata  <= r.send_data;
axis_miso_o.axis_tready <= r.rcv_ready;

-- WB connection
frag_wb_o.wb_stb     <= r.frag_wb_stb;
frag_wb_o.wb_cyc     <= r.frag_wb_stb;
frag_wb_o.wb_we      <= r.frag_wb_we;
frag_wb_o.wb_sel     <= "1111";
frag_wb_o.wb_adr     <= r.frag_wb_adr;
frag_wb_o.wb_dato    <= r.frag_wb_dato;

fb_wb_o.wb_stb       <= r.fb_wb_stb;
fb_wb_o.wb_cyc       <= r.fb_wb_stb;
fb_wb_o.wb_we        <= r.fb_wb_we;
fb_wb_o.wb_sel       <= "1111";
fb_wb_o.wb_adr       <= r.fb_wb_adr;
fb_wb_o.wb_dato      <= r.fb_wb_dato;
    
-- FIFO for received fragment data
fragment_fifo : entity work.afull_fifo
    generic map (
        DEPTH   => 4,
        WDT     => fragment_vec'length
    )
    port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        dat_i   => Fragment2Vec(r.fragment),
        dat_o   => frag_fifo_out,
        push_i  => r.frag_fifo_push, 
        pop_i   => r.frag_fifo_pop,
        full_o  => frag_fifo_full,
        empty_o => frag_fifo_empty
    );
    
-- FIFO for fragments to be written to FB
fb_fifo : entity work.afull_fifo
    generic map (
        DEPTH   => 5,
        WDT     => fb_fragment_vec'length
    )
    port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        dat_i   => FbFragment2Vec(r.fb_fragment),
        dat_o   => fb_fifo_out,
        push_i  => r.fb_fifo_push, 
        pop_i   => r.fb_fifo_pop,
        full_o  => fb_fifo_full,
        empty_o => fb_fifo_empty
    );
    
frag_busy <= (not frag_fifo_empty) or r.frag_fifo_push or (not fb_fifo_empty) or r.fb_fifo_push or r.frag_wb_stb or r.fb_wb_stb or to_sl(r.frag_state /= FRAG_IDLE);

-- WB clk processes
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
    variable v                  : reg_type;
    variable tmp_fb_fragment    : fb_fragment_type;
    variable tmp_blend_result   : blend_result_array;
begin
    v := r;
    
    v.send_last := '0';
    
    v.frag_fifo_push := '0';
    v.frag_fifo_pop := '0';
    v.fb_fifo_push := '0';
    v.fb_fifo_pop := '0';
    
    -- Stream receive FSM
    case r.rcv_state is
    
        when RCV_READY =>
            v.rcv_ready := '0';
            v.rcv_state := RCV_IDLE;
            
        when RCV_IDLE =>
            -- Wait for command on AXIS & check it without ready
            if (axis_mosi_i.axis_tvalid = '1') then
                case axis_mosi_i.axis_tdata is
                    when GPU_PIPE_CMD_FRAGMENT =>
                        if not frag_fifo_full then
                            v.rcv_state := RCV_FRAG_CMD;
                            v.rcv_ready := '1';
                        end if;

                    when GPU_PIPE_CMD_CLEAR_FB =>
                        -- wait till fragment ops is free to keep command order
                        if (r.clear_zb = '1') or (frag_busy = '0') then
                            v.rcv_state := RCV_READY;
                            v.rcv_ready := '1';
                            v.clear_fb := '1';
                        end if;

                    when GPU_PIPE_CMD_CLEAR_ZB =>
                        -- wait till fragment ops is free to keep command order
                        if (r.clear_fb = '1') or (frag_busy = '0') then
                            v.rcv_state := RCV_READY;
                            v.rcv_ready := '1';
                            v.clear_zb := '1';
                        end if;

                    when GPU_PIPE_CMD_FRAG_STATE =>
                        -- fragment stage state
                        -- wait till fragment ops is free to keep command order
                        if frag_busy = '0' then
                            v.rcv_state := RCV_FRAGSTATE_0;
                            v.rcv_ready := '1';
                        end if;

                    when others =>
                        -- wait till fragment ops is free to keep command order
                        if frag_busy = '0' then
                            v.rcv_ready := '1';
                            v.rcv_state := RCV_PASS_CMD;
                            v.rcv_pass_size := cmd_num_args(axis_mosi_i.axis_tdata);
                            v.rcv_pass_cnt := 0;
                        end if;
                end case;
            end if;
                
        when RCV_FRAGSTATE_0 =>
            v.rcv_state := RCV_FRAGSTATE_1;
                
        when RCV_FRAGSTATE_1 =>
            if (axis_mosi_i.axis_tvalid = '1') then
                v.rcv_state := RCV_IDLE;
                v.rcv_ready := '0';
                v.depth_test_enabled    := axis_mosi_i.axis_tdata(STATE_FRAG_DEPTH_BIT);
                v.depth_upd_enabled     := axis_mosi_i.axis_tdata(STATE_FRAG_DEPTHMASK_BIT);
                v.alpha_test_enabled    := axis_mosi_i.axis_tdata(STATE_FRAG_ALPHA_BIT);
                v.blending_enabled      := axis_mosi_i.axis_tdata(STATE_FRAG_BLEND_BIT);
                
                v.blend_sfunc   := axis_mosi_i.axis_tdata(STATE_FRAG_BLEND_SFUNC_HI downto STATE_FRAG_BLEND_SFUNC_LO);
                v.blend_dfunc   := axis_mosi_i.axis_tdata(STATE_FRAG_BLEND_DFUNC_HI downto STATE_FRAG_BLEND_DFUNC_LO);
            end if;

        when RCV_PASS_CMD =>
            v.rcv_ready := '1';
            if (axis_mosi_i.axis_tvalid = '1') then
                v.rcv_ready := '0';
                v.send_data := axis_mosi_i.axis_tdata;
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
            
        when RCV_FRAG_CMD =>
            -- acknowledge received command with ready
            v.rcv_state := RCV_XY;
            
        when RCV_XY =>
            if (axis_mosi_i.axis_tvalid = '1') then
                v.fragment.x := axis_mosi_i.axis_tdata(SCREEN_COORD_WDT-1 downto 0);
                v.fragment.y := axis_mosi_i.axis_tdata(SCREEN_COORD_WDT-1+16 downto 16);
                v.rcv_state := RCV_Z;
            end if;
            
        when RCV_Z =>
            if (axis_mosi_i.axis_tvalid = '1') then
                v.fragment.z := axis_mosi_i.axis_tdata(ZDEPTH_WDT-1 downto 0);
                v.rcv_state := RCV_ARGB;
            end if;
            
        when RCV_ARGB =>
            if (axis_mosi_i.axis_tvalid = '1') then
                v.fragment.argb := axis_mosi_i.axis_tdata;
                v.rcv_ready := '0';
                v.frag_fifo_push := '1';
                v.rcv_state := RCV_IDLE;
            end if;
            
        when RCV_AXIS_SEND =>
            if (axis_miso_i.axis_tready = '1') then
                v.send_valid := '0';
                v.send_last := '0';
                v.rcv_state := r.next_rcv_state;
                if r.next_rcv_state = RCV_PASS_CMD then
                    v.rcv_ready := '1';
                end if;
            end if;
        
    end case;
    
    -- Catch WB reply and zero stb
    if (r.frag_wb_stb and frag_wb_i.wb_ack) = '1' then
        v.frag_wb_stb := '0';
    end if;
    
    -- FSM to apply fragment ops (apart from blending)
    case r.frag_state is
        when FRAG_IDLE =>
            if r.clear_zb then
                -- !! make clear value configurable !!
                v.frag_state := FRAG_ZBUF_CLEAR;
                v.frag_wb_adr := ZBUF_BASE_ADDR;
                v.frag_wb_stb := '1';
                v.frag_wb_we := '1';
                v.frag_wb_dato := extl_vec(max_vec(ZDEPTH_WDT), 32);
                -- simulation hack to clear buffers fast --
                if FAST_CLEAR then
                    v.frag_wb_adr := max_vec(32);
                end if;
                -------------------------------------------
            elsif not frag_fifo_empty then
                v.proc_fragment := Vec2Fragment(frag_fifo_out);
                v.frag_fifo_pop := '1';
                
                -- synthesis translate_off
                assert (v.proc_fragment.x < SCREEN_WIDTH) and (v.proc_fragment.y < SCREEN_HEIGHT) report "FB coords out of bounds!" severity failure;
                -- synthesis translate_on

                v.fb_off := (SCREEN_HEIGHT-1 - v.proc_fragment.y) * to_slv(SCREEN_WIDTH, SCREEN_COORD_WDT) + v.proc_fragment.x;
                
                if r.alpha_test_enabled then
                    v.frag_state := FRAG_ALPHA_CHECK;
                elsif r.depth_test_enabled then
                    if ((r.frag_wb_stb = '0') or (frag_wb_i.wb_ack = '1')) then
                        v.frag_wb_adr := ZBUF_BASE_ADDR + v.fb_off;
                        v.frag_wb_stb := '1';
                        v.frag_wb_we := '0';
                        v.frag_state := FRAG_ZBUF_TEST;
                    else
                        v.frag_state := FRAG_ZBUF_READ;
                    end if;
                else
                    v.frag_state := FRAG_DONE;
                end if;
            end if;
            
        when FRAG_ALPHA_CHECK => 
            -- Alpha test
            -- !! make function & threshold value configurable !!
            if r.proc_fragment.argb(31 downto 24) > 171 then    
                v.frag_state := FRAG_ZBUF_READ;
                if r.depth_test_enabled then
                    v.frag_state := FRAG_ZBUF_READ;
                else
                    v.frag_state := FRAG_DONE;
                end if;
            else
                -- drop the fragment
                v.frag_state := FRAG_IDLE;
            end if;
            
        when FRAG_ZBUF_READ => 
            -- Read Z-buffer
            if ((r.frag_wb_stb = '0') or (frag_wb_i.wb_ack = '1')) then
                v.frag_wb_adr := ZBUF_BASE_ADDR + r.fb_off;
                v.frag_wb_stb := '1';
                v.frag_wb_we := '0';
                v.frag_state := FRAG_ZBUF_TEST;
            end if;
            
        when FRAG_ZBUF_TEST =>
            -- Perform depth test on read value
            -- !! make depth function configurable !!
            if (frag_wb_i.wb_ack = '1') then
                v.frag_state := FRAG_IDLE;
                if r.proc_fragment.z <= frag_wb_i.wb_dati(ZDEPTH_WDT-1 downto 0) then
                    if r.depth_upd_enabled then
                        v.frag_wb_stb := '1';
                        v.frag_wb_we := '1';
                        v.frag_wb_dato := extl_vec(r.proc_fragment.z, 32);
                    end if;
                    if not fb_fifo_full then
                        v.fb_fifo_push := '1';
                        v.fb_fragment.fb_addr := r.fb_off;
                        v.fb_fragment.argb := r.proc_fragment.argb;
                    else
                        v.frag_state := FRAG_DONE;
                    end if;
                end if;
            end if;
            
        when FRAG_ZBUF_CLEAR =>
            -- Clear Z-buffer
            if (frag_wb_i.wb_ack = '1') then
                if (r.frag_wb_adr < ZBUF_BASE_ADDR + FB_SIZE-1) then
                    v.frag_wb_adr := r.frag_wb_adr + 1;
                    v.frag_wb_stb := '1';
                else
                    v.frag_state := FRAG_IDLE;
                    v.clear_zb := '0';
                end if;
            end if;
            
        when FRAG_DONE =>
            if not fb_fifo_full then
                v.fb_fifo_push := '1';
                v.fb_fragment.fb_addr := r.fb_off;
                v.fb_fragment.argb := r.proc_fragment.argb;
                v.frag_state := FRAG_IDLE;
            end if;
        
    end case;
    
    -- Framebuffer writes
    if (r.fb_wb_stb and fb_wb_i.wb_ack) = '1' then
        v.fb_wb_stb := '0';
    end if;
    
    case r.fb_state is
        when FB_IDLE =>
            if (r.fb_wb_stb = '0') or (fb_wb_i.wb_ack = '1') then
                if r.clear_fb then
                    -- start framebuf clear
                    -- !! make clear value configurable !!
                    v.fb_wb_adr     := fb_addr_i;
                    v.fb_wb_stb     := '1';
                    v.fb_wb_we      := '1';
                    v.fb_wb_dato    := ZERO32;
                    v.fb_state      := FB_CLEAR;
                    -- simulation hack to clear buffers fast --
                    if FAST_CLEAR then
                        v.fb_wb_adr := max_vec(32);
                    end if;
                    -------------------------------------------
                elsif (fb_fifo_empty = '0') then
                    tmp_fb_fragment := Vec2FbFragment(fb_fifo_out);
                    v.fb_wb_stb := '1';
                    v.fb_wb_adr := fb_addr_i + tmp_fb_fragment.fb_addr;
                    if r.blending_enabled then
                        -- get color from fb for blending
                        v.fb_wb_we := '0';
                        v.fb_state := FB_BLEND0;
                        v.fb_fifo_pop   := '1';
                        
                        v.blend_array :=  Argb2Fixed(tmp_fb_fragment.argb);
                    else
                        -- write color to fb
                        v.fb_wb_we      := '1';
                        v.fb_fifo_pop   := '1';
                        v.fb_wb_dato    := tmp_fb_fragment.argb;
                    end if;
                end if;
            end if;
            
        when FB_CLEAR =>
            if (r.fb_wb_adr < fb_addr_i + FB_SIZE-1) then
                if fb_wb_i.wb_ack then
                    v.fb_wb_adr     := r.fb_wb_adr + 1;
                    v.fb_wb_stb     := '1';
                end if;
            else
                v.clear_fb  := '0';
                v.fb_state  := FB_IDLE;
            end if;
            
        when FB_BLEND0 =>
            -- wait for color from FB and precalc some blending factors
            for i in 0 to NCOLORS-1 loop
                v.src_blend(i) := resize(r.blend_array(i) * BlendFactor(r.blend_sfunc, r.blend_array, i), -1, -COLOR_BITS);
            end loop;
                
            if (fb_wb_i.wb_ack = '1') then
                v.dst_blend := fb_wb_i.wb_dati;
                
                v.fb_state      := FB_BLEND1;
            end if;
            
        when FB_BLEND1 =>
            -- wait for color from FB
            for i in 0 to NCOLORS-1 loop
                -- calc blending in fixed point
                tmp_blend_result(i) := r.src_blend(i) + resize(Argb2Fixed(r.dst_blend)(i) * BlendFactor(r.blend_dfunc, r.blend_array, i), -1, -COLOR_BITS);
            end loop;
            
            -- write blended color to FB at same address
            v.fb_wb_stb     := '1';
            v.fb_wb_we      := '1';
            v.fb_wb_dato    := Fixed2Argb(tmp_blend_result);
            v.fb_state      := FB_IDLE;
    
    end case;
    
    rin <= v;
    
end process;
    
end architecture behavioral;
