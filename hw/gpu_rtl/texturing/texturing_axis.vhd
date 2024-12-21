------------------------------------------------------------------------
------------------------------------------------------------------------
--
-- Texturing stage
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

entity texturing_axis is
    generic (
        TEX_BASE_ADDR : vec32
    );
    port (
            clk_i       : in  std_logic;
            rst_i       : in  std_logic;
            error_o     : out std_logic;

            axis_mosi_i : in  global_axis_mosi_type;
            axis_miso_o : out global_axis_miso_type;

            axis_mosi_o : out global_axis_mosi_type;
            axis_miso_i : in  global_axis_miso_type;
            
            wb_o        : out wishbone_mosi_type;
            wb_i        : in  wishbone_miso_type
        );
end texturing_axis;

architecture behavioral of texturing_axis is

    type tex_fragment_type is record
        x       : screen_coord_vec;
        y       : screen_coord_vec;
        z       : zdepth_vec;
        tx      : vec32;
        ty      : vec32;
    end record;
    subtype tex_fragment_vec is std_logic_vector(SCREEN_COORD_WDT*2+ZDEPTH_WDT+32*2-1 downto 0);
    constant ZERO_TEX_FRAGMENT : tex_fragment_type := (ZERO_SCREENC, ZERO_SCREENC, ZERO_ZDEPTH, ZERO32, ZERO32);
    
    function TexFragment2Vec(f : tex_fragment_type) return tex_fragment_vec is
    begin
        return f.ty & f.tx & f.z & f.y & f.x;
    end function;
    
    function Vec2TexFragment(v : tex_fragment_vec) return tex_fragment_type is
        variable f : tex_fragment_type;
    begin
        f.x := v(SCREEN_COORD_WDT-1 downto 0);
        f.y := v(SCREEN_COORD_WDT*2-1 downto SCREEN_COORD_WDT);
        f.z := v(SCREEN_COORD_WDT*2+ZDEPTH_WDT-1 downto SCREEN_COORD_WDT*2);
        f.tx := v(SCREEN_COORD_WDT*2+ZDEPTH_WDT+32-1 downto SCREEN_COORD_WDT*2+ZDEPTH_WDT);
        f.ty := v(SCREEN_COORD_WDT*2+ZDEPTH_WDT+64-1 downto SCREEN_COORD_WDT*2+ZDEPTH_WDT+32);
        return f;
    end function;
    
    constant FIXED_SIGN_WDT     : integer := 1;
    constant FIXED_INT_WDT      : integer := 0;
    constant FIXED_FRAC_WDT     : integer := 15;
    constant FIXED_WDT          : integer := FIXED_SIGN_WDT+FIXED_INT_WDT+FIXED_FRAC_WDT;
    
    -- Cut fractional part from float with wrapping and represent as fixed point
    function WrapToFixed(f : vec32) return sfixed is
        variable shift      : integer range -127 to 127;
        variable off        : integer range -127 to 127;
        variable mant       : std_logic_vector(FLOAT_MANT_WDT downto 0);
        variable fixed_vec  : std_logic_vector(FIXED_WDT-1 downto 0);
        variable fixed      : sfixed(FIXED_INT_WDT downto -FIXED_FRAC_WDT);
    begin
        shift := to_uint(f(FLOAT_EXP_HI downto FLOAT_EXP_LO)) - 127 - FIXED_INT_WDT;

        mant := "1" & f(FLOAT_MANT_HI downto FLOAT_MANT_LO);   -- add implicit 1
 
        -- shift left or right
        for i in FIXED_WDT-2 downto 0 loop
            off := i+(FLOAT_MANT_WDT-FIXED_WDT+1-shift);
            if (off >= 0) and (off <= FLOAT_MANT_WDT) then
                fixed_vec(i) := mant(off);
            else
                fixed_vec(i) := '0';
            end if;
        end loop;
        
        -- add sign
        fixed_vec(FIXED_WDT-1) := '0';
        
        fixed := to_sfixed(fixed_vec, FIXED_INT_WDT, -FIXED_FRAC_WDT);
        
        -- invert in case of negative (wrap)
        if f(FLOAT_SIGN) = '1' then
            fixed(fixed'high-1 downto fixed'low) := not fixed(fixed'high-1 downto fixed'low);
        end if;
        
        return fixed;
    end;
    
    constant TEXSIZE_WDT        : integer := 16;
    constant TEXSIZE_FIXED_INT  : integer := TEXSIZE_WDT-1;
    constant TEXSIZE_FIXED_FRAC : integer := 0;
    
    type rcv_state_type is (RCV_IDLE, RCV_BIND_0, RCV_BIND_PTR, RCV_BIND_SIZE, RCV_PASS_CMD, RCV_TEX_CMD, RCV_XY, RCV_Z, RCV_TX, RCV_TY, RCV_AXIS_SEND);
    type calc_state_type is (CALC_IDLE, CALC_ST, CALC_UV, CALC_REQ);
    type send_state_type is (SEND_IDLE, SEND_XY, SEND_Z, SEND_ARGB, SEND_FINISH);

    type reg_type is record
        rcv_state           : rcv_state_type;
        next_rcv_state      : rcv_state_type;
        calc_state          : calc_state_type;
        send_state          : send_state_type;
            
        error               : std_logic;
        rcv_ready           : std_logic;
        send_valid          : std_logic;
        send_valid_frag     : std_logic;
        send_last           : std_logic;
        send_data           : std_logic_vector(GLOBAL_AXIS_DATA_WIDTH-1 downto 0);
            
        rcv_pass_cnt        : integer range 0 to 255;
        rcv_pass_size       : integer range 0 to 255;
            
        tex_size_x          : std_logic_vector(TEXSIZE_WDT-1 downto 0);
        tex_size_y          : std_logic_vector(TEXSIZE_WDT-1 downto 0);
        tex_adr             : vec32;
        
        frag_fifo_push      : std_logic;
        frag_fifo_pop       : std_logic;
        tex_frag_fifo_push  : std_logic;
        tex_frag_fifo_pop   : std_logic;
        
        fragment            : fragment_type;
        sending_fragment    : fragment_type;
        tex_fragment        : tex_fragment_type;
        req_tex_fragment    : tex_fragment_type;
        proc_tex_fragment   : tex_fragment_type;
        
        s_fixed             : sfixed(FIXED_INT_WDT downto -FIXED_FRAC_WDT);
        t_fixed             : sfixed(FIXED_INT_WDT downto -FIXED_FRAC_WDT);
        
        u                   : std_logic_vector(TEXSIZE_WDT-1 downto 0);
        v                   : std_logic_vector(TEXSIZE_WDT-1 downto 0);
        
        wb_stb              : std_logic;
        wb_adr              : vec32;
    end record;
    
    constant r_rst  : reg_type := (
        RCV_IDLE, RCV_IDLE, CALC_IDLE, SEND_IDLE, 
        '0', '0', '0', '0', '0', ZERO32,
        0, 0,
        (others => '0'), (others => '0'), ZERO32,
        '0', '0', '0', '0',
        ZERO_FRAGMENT, ZERO_FRAGMENT, ZERO_TEX_FRAGMENT, ZERO_TEX_FRAGMENT, ZERO_TEX_FRAGMENT,
        (others => '0'), (others => '0'),
        (others => '0'), (others => '0'), 
        '0', ZERO32
    );
    signal r, rin   : reg_type;
    
    signal fifo_mosi            : global_axis_mosi_type;
    signal fifo_miso            : global_axis_miso_type;
    signal tex_busy             : std_logic;
    
    signal frag_fifo_out        : fragment_vec;
    signal frag_fifo_full       : std_logic;
    signal frag_fifo_empty      : std_logic;
    signal tex_frag_fifo_out    : tex_fragment_vec;
    signal tex_frag_fifo_full   : std_logic;
    signal tex_frag_fifo_empty  : std_logic;

begin

error_o <= r.error;

-- WB connection
wb_o.wb_stb     <= r.wb_stb;
wb_o.wb_cyc     <= r.wb_stb;
wb_o.wb_we      <= '0';
wb_o.wb_sel     <= "0000";
wb_o.wb_adr     <= r.wb_adr;
wb_o.wb_dato    <= (others => '0');

-- Stream connections
axis_miso_o.axis_tready <= r.rcv_ready;

-- FIFO for stream output
out_fifo : entity work.stream_fifo
generic map (
    DEPTH   => 4
)
port map (
    clk_i       => clk_i,
    rst_i       => rst_i,

    axis_mosi_i => fifo_mosi,
    axis_miso_o => fifo_miso,

    axis_mosi_o => axis_mosi_o,
    axis_miso_i => axis_miso_i
);

fifo_mosi.axis_tvalid <= r.send_valid or r.send_valid_frag;
fifo_mosi.axis_tlast  <= r.send_last;
fifo_mosi.axis_tdata  <= r.send_data;
assert((r.send_valid and r.send_valid_frag) /= '1') severity failure;

-- FIFO for texture fragment data
tex_fragment_fifo : entity work.afull_fifo
    generic map (
        DEPTH   => 3,
        WDT     => tex_fragment_vec'length
    )
    port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        dat_i   => TexFragment2Vec(r.tex_fragment),
        dat_o   => tex_frag_fifo_out,
        push_i  => r.tex_frag_fifo_push, 
        pop_i   => r.tex_frag_fifo_pop,
        full_o  => tex_frag_fifo_full,
        empty_o => tex_frag_fifo_empty
    );
    
-- FIFO for resulting fragment data (? replace with couple of fragment registers ?)
fragment_fifo : entity work.afull_fifo
    generic map (
        DEPTH   => 2,
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
    
tex_busy <= (not frag_fifo_empty) or (not tex_frag_fifo_empty) or r.frag_fifo_push or r.wb_stb or to_sl(r.calc_state /= CALC_IDLE) or to_sl(r.send_state /= SEND_IDLE);

-- Sequential process
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

-- Combinational process
async_proc : process(all)
    variable v          : reg_type;
    variable tmp_fixed  : sfixed(TEXSIZE_WDT downto -FIXED_FRAC_WDT);
begin
    v := r;
    
    v.tex_frag_fifo_push := '0';
    v.send_last := '0';
    
    if r.send_valid and r.send_valid_frag then
        v.error := '1';
    end if;
    
    -- Stream receive FSM
    case r.rcv_state is
            
        when RCV_IDLE =>
            -- Wait for command on AXIS & check it without ready
            if (axis_mosi_i.axis_tvalid = '1') then
                case axis_mosi_i.axis_tdata is
                    when GPU_PIPE_CMD_TEXFRAGMENT =>
                        if not tex_frag_fifo_full then
                            v.rcv_state := RCV_TEX_CMD;
                            v.rcv_ready := '1';
                        end if;

                    when GPU_PIPE_CMD_BINDTEXTURE =>
                        -- wait till texturing is free to keep command order
                        if tex_busy = '0' then
                            v.rcv_state := RCV_BIND_0;
                            v.rcv_ready := '1';
                        end if;

                    when others =>
                        -- wait till texturing is free to keep command order
                        if tex_busy = '0' then
                            v.rcv_ready := '1';
                            v.rcv_state := RCV_PASS_CMD;
                            v.rcv_pass_size := cmd_num_args(axis_mosi_i.axis_tdata);
                            v.rcv_pass_cnt := 0;
                        end if;
                end case;
            end if;
                
        when RCV_BIND_0 =>
            -- ! instead of separate state set rcv_ready in idle if tex_busy=1 and wait for r.rcv_ready!
            if (axis_mosi_i.axis_tvalid = '1') then
                v.rcv_state := RCV_BIND_PTR;
            end if;
                
        when RCV_BIND_PTR =>
            if (axis_mosi_i.axis_tvalid = '1') then
                v.rcv_state := RCV_BIND_SIZE;
                v.tex_adr := "00" & axis_mosi_i.axis_tdata(31 downto 2);
            end if;
                
        when RCV_BIND_SIZE =>
            if (axis_mosi_i.axis_tvalid = '1') then
                v.rcv_state := RCV_IDLE;
                v.rcv_ready := '0';
                v.tex_size_x := axis_mosi_i.axis_tdata(TEXSIZE_WDT-1 downto 0);
                v.tex_size_y := axis_mosi_i.axis_tdata(15+TEXSIZE_WDT downto 16);
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
            
        when RCV_TEX_CMD =>
            -- acknowledge received command with ready
            -- ! instead of separate state set rcv_ready in idle if tex_busy=1 or tex cmd and wait for r.rcv_ready!
            if (axis_mosi_i.axis_tvalid = '1') then
                v.rcv_state := RCV_XY;
            end if;
            
        when RCV_XY =>
            if (axis_mosi_i.axis_tvalid = '1') then
                v.tex_fragment.x := axis_mosi_i.axis_tdata(SCREEN_COORD_WDT-1 downto 0);
                v.tex_fragment.y := axis_mosi_i.axis_tdata(SCREEN_COORD_WDT-1+16 downto 16);
                v.rcv_state := RCV_Z;
            end if;
            
        when RCV_Z =>
            if (axis_mosi_i.axis_tvalid = '1') then
                v.tex_fragment.z := axis_mosi_i.axis_tdata(ZDEPTH_WDT-1 downto 0);
                v.rcv_state := RCV_TX;
            end if;
            
        when RCV_TX =>
            if (axis_mosi_i.axis_tvalid = '1') then
                v.tex_fragment.tx := axis_mosi_i.axis_tdata;
                v.rcv_state := RCV_TY;
            end if;
            
        when RCV_TY =>
            if (axis_mosi_i.axis_tvalid = '1') then
                v.tex_fragment.ty := axis_mosi_i.axis_tdata;
                v.rcv_ready := '0';
                v.tex_frag_fifo_push := '1';
                v.rcv_state := RCV_IDLE;
            end if;
            
        when RCV_AXIS_SEND =>
            if (fifo_miso.axis_tready = '1') then
                v.send_valid := '0';
                v.send_last := '0';
                v.rcv_state := r.next_rcv_state;
                if r.next_rcv_state = RCV_PASS_CMD then
                    v.rcv_ready := '1';
                end if;
            end if;
        
    end case;
    
    v.frag_fifo_push := '0';
    v.frag_fifo_pop := '0';
    v.tex_frag_fifo_pop := '0';
    
    -- Catch WB reply and push it into fragment FIFO
    if (r.wb_stb and wb_i.wb_ack) = '1' then
        v.wb_stb := '0';
        v.fragment := (
            r.req_tex_fragment.x,
            r.req_tex_fragment.y,
            r.req_tex_fragment.z,
            /*A*/ wb_i.wb_dati(31 downto 24) & /*R*/ wb_i.wb_dati(7 downto 0) & /*G*/ wb_i.wb_dati(15 downto 8) & /*B*/ wb_i.wb_dati(23 downto 16)
        );
        v.frag_fifo_push := '1';
    end if;
    
    -- FSM to calculate texture address and send WB requests
    case r.calc_state is
        when CALC_IDLE =>
            if not tex_frag_fifo_empty then
                v.calc_state := CALC_ST;
                v.proc_tex_fragment := Vec2TexFragment(tex_frag_fifo_out);
                v.tex_frag_fifo_pop := '1';
            end if;
            
        when CALC_ST => 
            -- Wrap mode - REPEAT
            v.s_fixed := WrapToFixed(r.proc_tex_fragment.tx);
            v.t_fixed := WrapToFixed(r.proc_tex_fragment.ty);
            v.calc_state := CALC_UV;
            
        when CALC_UV =>
            -- TEXTURE_MIN_FILTER - NEAREST
            tmp_fixed := r.s_fixed * to_sfixed(r.tex_size_x, TEXSIZE_FIXED_INT, TEXSIZE_FIXED_FRAC); 
            v.u := to_slv(tmp_fixed(TEXSIZE_WDT-1 downto 0));
            tmp_fixed := r.t_fixed * to_sfixed(r.tex_size_y, TEXSIZE_FIXED_INT, TEXSIZE_FIXED_FRAC); 
            v.v := to_slv(tmp_fixed(TEXSIZE_WDT-1 downto 0));
            
            v.calc_state := CALC_REQ;
        
        when CALC_REQ =>
            if (frag_fifo_full = '0') and ((r.wb_stb = '0') or (wb_i.wb_ack = '1')) then
                v.wb_stb := '1';
                v.wb_adr := TEX_BASE_ADDR or (r.tex_adr + (r.v * r.tex_size_x + r.u));
                v.req_tex_fragment := r.proc_tex_fragment;
                if tex_frag_fifo_empty then
                    v.calc_state := CALC_IDLE;
                else
                    v.calc_state := CALC_ST;
                    v.proc_tex_fragment := Vec2TexFragment(tex_frag_fifo_out);
                    v.tex_frag_fifo_pop := '1';
                end if;
            end if;
        
    end case;
    
    -- FSM to pass data from processed fragments FIFO to stream output FIFO
    case (r.send_state) is
        when SEND_IDLE =>
            v.send_valid_frag := '0';
            if frag_fifo_empty = '0' then
                v.sending_fragment := Vec2Fragment(frag_fifo_out);
                v.frag_fifo_pop := '1';
                v.send_valid_frag := '1';
                v.send_data := GPU_PIPE_CMD_FRAGMENT;
                v.send_state := SEND_XY;
            end if;
            
        when SEND_XY =>
            v.send_valid_frag := '1';
            if (fifo_miso.axis_tready = '1') then
                v.send_data := extl_vec(r.sending_fragment.y, 16) & extl_vec(r.sending_fragment.x, 16);
                v.send_state := SEND_Z;
            end if;
            
        when SEND_Z =>
            v.send_valid_frag := '1';
            if (fifo_miso.axis_tready = '1') then
                v.send_data := extl_vec(r.sending_fragment.z, 32);
                v.send_state := SEND_ARGB;
            end if;
            
        when SEND_ARGB =>
            v.send_valid_frag := '1';
            v.send_last := '1';
            if (fifo_miso.axis_tready = '1') then
                v.send_data := r.sending_fragment.argb;
                v.send_state := SEND_FINISH;
            end if;
            
        when SEND_FINISH =>
            v.send_valid_frag := '1';
            v.send_last := '1';
            if (fifo_miso.axis_tready = '1') then
                if frag_fifo_empty = '0' then
                    v.sending_fragment := Vec2Fragment(frag_fifo_out);
                    v.frag_fifo_pop := '1';
                    v.send_valid_frag := '1';
                    v.send_data := GPU_PIPE_CMD_FRAGMENT;
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
    
end architecture behavioral;
