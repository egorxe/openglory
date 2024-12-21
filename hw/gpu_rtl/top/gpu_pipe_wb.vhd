library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.gpu_pkg.all;

entity gpu_pipe_wb is
    generic (
        SCREEN_WIDTH    : integer := 640;
        SCREEN_HEIGHT   : integer := 480;
        ADDR_WIDTH      : integer := 32;
        DATA_WIDTH      : integer := 32;
        FAST_CLEAR      : boolean := False;     -- simulation only!
        FB_BASE_REG     : vec32   := X"F0008000";
        FB_BASE_ADDR0   : vec32   := X"40C00000";
        FB_BASE_ADDR1   : vec32   := X"40D30000";
        ZBUF_BASE_ADDR  : vec32   := X"40A00000";
        DRAM_ADDR       : vec32   := X"40000000";   
        CAPABILITIES    : vec32   := X"00010001";
        BOARD_NAME      : string  := "AXKU_040"     -- should be 8 chars
    );
    port (
        clk_i           : in  std_logic;
        gpu_clk_i       : in  std_logic;
		rst_i           : in  std_logic;
		gpu_rst_i       : in  std_logic;
		resetme_o       : out std_logic;
        
        axis_cmd_valid_i    : in  std_logic;
        axis_cmd_data_i     : in  vec32;
        axis_cmd_ready_o    : out std_logic;
        
        wb_cmd_valid_o      : out std_logic;
        wb_cmd_data_o       : out vec32;
        wb_cmd_ready_i      : in  std_logic;
        
        axis_rast_valid_o   : out std_logic;
        axis_rast_data_o    : out vec32;
        axis_rast_ready_i   : in  std_logic;
        
        axis_tex_valid_i    : in  std_logic;
        axis_tex_data_i     : in  vec32;
        axis_tex_ready_o    : out std_logic;
        
        cmd_wb_adr_o    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        cmd_wb_dat_o    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        cmd_wb_sel_o    : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        cmd_wb_we_o     : out std_logic;
        cmd_wb_stb_o    : out std_logic;
        cmd_wb_cyc_o    : out std_logic;
        cmd_wb_dat_i    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        cmd_wb_ack_i    : in  std_logic;
        
        tex_wb_adr_o    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        tex_wb_dat_o    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        tex_wb_sel_o    : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        tex_wb_we_o     : out std_logic;
        tex_wb_stb_o    : out std_logic;
        tex_wb_cyc_o    : out std_logic;
        tex_wb_dat_i    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        tex_wb_ack_i    : in  std_logic;
        
        frag_wb_adr_o   : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        frag_wb_dat_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        frag_wb_sel_o   : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        frag_wb_we_o    : out std_logic;
        frag_wb_stb_o   : out std_logic;
        frag_wb_cyc_o   : out std_logic;
        frag_wb_dat_i   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        frag_wb_ack_i   : in  std_logic;
        
        fb_wb_adr_o     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        fb_wb_dat_o     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        fb_wb_sel_o     : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        fb_wb_we_o      : out std_logic;
        fb_wb_stb_o     : out std_logic;
        fb_wb_cyc_o     : out std_logic;
        fb_wb_dat_i     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        fb_wb_ack_i     : in  std_logic;
        
        wbs_adr_i       : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        wbs_dat_i       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        wbs_sel_i       : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        wbs_we_i        : in  std_logic;
        wbs_stb_i       : in  std_logic;
        wbs_cyc_i       : in  std_logic;
        wbs_dat_o       : out std_logic_vector(DATA_WIDTH-1 downto 0);
        wbs_ack_o       : out std_logic;
        
        cache_inv_o     : out std_logic_vector(2 downto 0);
        cache_inv_i     : in  std_logic_vector(2 downto 0)
    );
end entity gpu_pipe_wb;

architecture arch of gpu_pipe_wb is

    constant CMD_WDT        : integer := 18;
    constant ABASE_WDT      : integer := 30;
    constant ZERO_CMD       : std_logic_vector(CMD_WDT-1 downto 0) := (others => '0');
    
    function GetCurFbAddr(fb_sel : std_logic) return std_logic_vector is
    begin
        if fb_sel then
            return FB_BASE_ADDR1(31 downto 2);
        else
            return FB_BASE_ADDR0(31 downto 2);
        end if;
    end function;

    type wb_state_type is (IDLE, SWITCH_FB_0, SWITCH_FB_1, SWITCH_FB_2, READ_CMDS, PUSH_CMD, REQ);
    type stream_state_type is (STREAM_RCV_CMD, STREAM_RCV_JUNK);

    type reg_type is record
        state           : wb_state_type;
        next_state      : wb_state_type;
        stream_state    : stream_state_type;
            
        wb_stb          : std_logic;
        wb_we           : std_logic;
        wb_adr          : std_logic_vector(ADDR_WIDTH-1 downto 0);
        wb_dat_out      : std_logic_vector(DATA_WIDTH-1 downto 0);
        wb_dat_in       : std_logic_vector(DATA_WIDTH-1 downto 0);
            
        wbs_dat_out     : std_logic_vector(DATA_WIDTH-1 downto 0);
        wbs_ack         : std_logic;
    
        sync_cnt        : vec32;
        cmd_reads       : vec32;
        errors_gpu      : vec32;
    
        fb_sel          : std_logic;
        resetme         : std_logic;
            
        reading_cmd     : std_logic;
        switch_fb       : std_logic;
            
        fb_base         : std_logic_vector(ABASE_WDT-1 downto 0);
        cmd_base        : std_logic_vector(ABASE_WDT-1 downto 0);
            
        cmd_cnt         : std_logic_vector(CMD_WDT-1 downto 0);
        cmd_size        : std_logic_vector(CMD_WDT-1 downto 0);
        cmd_fifo_push   : std_logic;
        cmd_fifo_pop    : std_logic;
        wb_cmd_valid    : std_logic;
        wb_cmd_data     : vec32;
        
        -- synthesis translate_off
        report_msg      : string(1 to 100);
        report_sev      : severity_level;
        -- synthesis translate_on
        
        junk_cnt        : integer range 0 to 255;
        junk_size       : integer range 0 to 255;
            
        cache_inv       : std_logic_vector(2 downto 0);
    end record;
    
    constant r_rst  : reg_type := (
        IDLE, IDLE, STREAM_RCV_CMD,
        '0', '1', ZERO32, ZERO32, ZERO32, 
        ZERO32, '0',
        ZERO32, ZERO32, ZERO32,
        '0', '0',
        '0', '0',
        FB_BASE_REG(31 downto 2), DRAM_ADDR(31 downto 2),
        ZERO_CMD, ZERO_CMD, '0', '0', '0', ZERO32,
        -- synthesis translate_off
        (others => ' '), note,
        -- synthesis translate_on
        0, 0,
        "000"
    );
    signal r, rin   : reg_type;
    
    signal tex_error        : std_logic;
    signal rast_debug       : vec32;
        
    -- AXI stream records
    signal input_to_vertex  : global_axis_mosi_type;
    signal vertex_to_input  : global_axis_miso_type;
    
    signal vertex_to_rast   : global_axis_mosi_type;
    signal rast_to_vertex   : global_axis_miso_type;
    
    signal texturing_to_frag: global_axis_mosi_type;
    signal frag_to_texturing: global_axis_miso_type;
    
    signal rast_to_cc       : global_axis_mosi_type;
    signal cc_to_rast       : global_axis_miso_type;
    
    signal cc_to_texturing  : global_axis_mosi_type;
    signal texturing_to_cc  : global_axis_miso_type;
    
    signal frag_to_final    : global_axis_mosi_type;
    signal final_to_frag    : global_axis_miso_type;
    
    -- Wishbone records
    signal tex_wb_mosi      : wishbone_mosi_type;
    signal tex_wb_miso      : wishbone_miso_type;
    
    signal frag_wb_mosi     : wishbone_mosi_type;
    signal frag_wb_miso     : wishbone_miso_type;
    
    signal fb_wb_mosi       : wishbone_mosi_type;
    signal fb_wb_miso       : wishbone_miso_type;
    
    -- Cmd fifo
    signal cmd_fifo_full    : std_logic;
    signal cmd_fifo_empty   : std_logic;
    signal cur_cmd_base     : std_logic_vector(ABASE_WDT-1 downto 0);
    signal cur_cmd_size     : std_logic_vector(CMD_WDT-1 downto 0);

begin

vertex_transform : entity work.vertex_transform_axis_type_wrapper
    port map (
        clk_i           => gpu_clk_i,
        rst_i           => gpu_rst_i,
        
        axis_mosi_i     => input_to_vertex,
        axis_miso_o     => vertex_to_input,

        axis_mosi_o     => vertex_to_rast,
        axis_miso_i     => rast_to_vertex
    );

rasterizer : entity work.rasterizer_axis_type_wrapper
    port map (
        clk_i           => gpu_clk_i,
        rst_i           => gpu_rst_i,
        
        axis_mosi_i     => vertex_to_rast,
        axis_miso_o     => rast_to_vertex,

        axis_mosi_o     => rast_to_cc,
        axis_miso_i     => cc_to_rast,
        
        debug_o         => rast_debug
    );

TEXTURING: if TEXTURING_UNITS = 0 generate

texturing_to_frag <= cc_to_texturing;
texturing_to_cc <= frag_to_texturing;
tex_wb_mosi.wb_stb <= '0';
tex_wb_mosi.wb_cyc <= '0';
tex_error <= '0';

else generate
texturing_unit : entity work.texturing_axis
    generic map (
        TEX_BASE_ADDR   => "00" & DRAM_ADDR(31 downto 2)
    )
    port map (
        clk_i           => clk_i,
        rst_i           => rst_i,
        error_o         => tex_error,
        
        axis_mosi_i     => cc_to_texturing,
        axis_miso_o     => texturing_to_cc,

        axis_mosi_o     => texturing_to_frag,
        axis_miso_i     => frag_to_texturing,
        
        wb_o            => tex_wb_mosi,
        wb_i            => tex_wb_miso
    );
end generate;

fragment_ops : entity work.fragment_axis
    generic map (
        ZBUF_BASE_ADDR  => "00" & ZBUF_BASE_ADDR(31 downto 2),
        FAST_CLEAR      => FAST_CLEAR
    )
    port map (
        clk_i           => clk_i,
        rst_i           => rst_i,
        
        axis_mosi_i     => texturing_to_frag,
        axis_miso_o     => frag_to_texturing,

        axis_mosi_o     => frag_to_final,
        axis_miso_i     => final_to_frag,
        
        frag_wb_o       => frag_wb_mosi,
        frag_wb_i       => frag_wb_miso,
        
        fb_addr_i       => "00" & GetCurFbAddr(r.fb_sel),
        fb_wb_o         => fb_wb_mosi,
        fb_wb_i         => fb_wb_miso
    );

final_to_frag.axis_tready <= '1';

---------------------------- IO connections ---------------------------- 
-- Command WB master
cmd_wb_stb_o    <= r.wb_stb;
cmd_wb_cyc_o    <= r.wb_stb;
cmd_wb_adr_o    <= r.wb_adr(31 downto 0);
cmd_wb_dat_o    <= r.wb_dat_out;
cmd_wb_we_o     <= r.wb_we;
cmd_wb_sel_o    <= "1111";

-- Texturing WB master
tex_wb_stb_o    <= tex_wb_mosi.wb_stb;
tex_wb_cyc_o    <= tex_wb_mosi.wb_cyc;
tex_wb_adr_o    <= tex_wb_mosi.wb_adr;
tex_wb_dat_o    <= tex_wb_mosi.wb_dato;
tex_wb_we_o     <= tex_wb_mosi.wb_we;
tex_wb_sel_o    <= tex_wb_mosi.wb_sel;
tex_wb_miso     <= (wb_ack => tex_wb_ack_i, wb_dati => tex_wb_dat_i);

-- Fragment WB master
frag_wb_stb_o   <= frag_wb_mosi.wb_stb;
frag_wb_cyc_o   <= frag_wb_mosi.wb_cyc;
frag_wb_adr_o   <= frag_wb_mosi.wb_adr;
frag_wb_dat_o   <= frag_wb_mosi.wb_dato;
frag_wb_we_o    <= frag_wb_mosi.wb_we;
frag_wb_sel_o   <= frag_wb_mosi.wb_sel;
frag_wb_miso    <= (wb_ack => frag_wb_ack_i, wb_dati => frag_wb_dat_i);

-- Framebuffer WB master
fb_wb_stb_o     <= fb_wb_mosi.wb_stb;
fb_wb_cyc_o     <= fb_wb_mosi.wb_cyc;
fb_wb_adr_o     <= fb_wb_mosi.wb_adr;
fb_wb_dat_o     <= fb_wb_mosi.wb_dato;
fb_wb_we_o      <= fb_wb_mosi.wb_we;
fb_wb_sel_o     <= fb_wb_mosi.wb_sel;
fb_wb_miso      <= (wb_ack => fb_wb_ack_i, wb_dati => fb_wb_dat_i);

-- WB slave
wbs_ack_o   <= r.wbs_ack;
wbs_dat_o   <= r.wbs_dat_out;

-- Cmd FIFO
wb_cmd_valid_o              <= r.wb_cmd_valid;
wb_cmd_data_o               <= r.wb_cmd_data;
input_to_vertex.axis_tvalid <= axis_cmd_valid_i;
input_to_vertex.axis_tdata  <= axis_cmd_data_i;
axis_cmd_ready_o            <= vertex_to_input.axis_tready;

-- Crossclock FIFO
axis_rast_valid_o           <= rast_to_cc.axis_tvalid;
axis_rast_data_o            <= rast_to_cc.axis_tdata;
cc_to_rast.axis_tready      <= axis_rast_ready_i;
cc_to_texturing.axis_tvalid <= axis_tex_valid_i;
cc_to_texturing.axis_tdata  <= axis_tex_data_i;
axis_tex_ready_o            <= texturing_to_cc.axis_tready;

-- System
resetme_o   <= r.resetme;
cache_inv_o <= r.cache_inv;
------------------------------------------------------------------------ 

-- FIFO for command buffer descriptors
cmd_fifo : entity work.afull_fifo
    generic map (
        ALLOW_FULL_EMPTY    => False,
        DEPTH               => 3,
        WDT                 => ABASE_WDT+CMD_WDT
    )
    port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        dat_i   => r.cmd_size & r.cmd_base,
        
        dat_o(ABASE_WDT-1 downto 0)                 => cur_cmd_base,
        dat_o(ABASE_WDT+CMD_WDT-1 downto ABASE_WDT) => cur_cmd_size,
        
        push_i  => r.cmd_fifo_push, 
        pop_i   => r.cmd_fifo_pop,
        full_o  => cmd_fifo_full,
        empty_o => cmd_fifo_empty
    );


-- Sequencial process
seq_proc : process(clk_i)
begin
    if Rising_edge(clk_i) then
        if rst_i = '1' then
            r <= r_rst;
        else
            r <= rin;
            -- synthesis translate_off
            if r.report_msg(1) /= ' ' then
                report r.report_msg severity r.report_sev;
                r.report_msg <= (others => ' ');
            end if;
            -- synthesis translate_on
        end if;
    end if;
end process;

-- Combinational process
async_proc : process(all)
    variable v : reg_type;
    -- synthesis translate_off
    procedure report_sync(s : string; l : severity_level) is
    begin
        for i in v.report_msg'range loop
            if i <= s'right then
                v.report_msg(i) := s(i);
            else
                v.report_msg(i) := ' ';
            end if;
        end loop;
        
        v.report_sev := l;
    end;
    -- synthesis translate_on
begin
    v := r;
    
    if tex_error then
        v.errors_gpu(1) := '1';
    end if;
    
    v.wbs_ack       := '0';
    
    if wb_cmd_ready_i then
        v.wb_cmd_valid := '0';
    end if;
    
    v.cmd_fifo_push := '0';
    v.cmd_fifo_pop  := '0';
    v.cache_inv     := "000";

    -- WB slave
    if wbs_stb_i and wbs_cyc_i then
        v.wbs_ack := '1';
        if wbs_we_i then
            case wbs_adr_i(3 downto 0) is
                -- control reg
                when X"0" =>
                    v.switch_fb     := r.switch_fb or wbs_dat_i(1);
                    
                -- size reg
                when X"1" =>
                    v.cmd_size := wbs_dat_i(CMD_WDT-1 downto 0);
                    v.cmd_fifo_push := not r.wbs_ack;   -- only 1 clock
                    
                -- cmd base reg
                when X"2" =>
                    v.cmd_base := wbs_dat_i(31 downto 2);
                    
                -- fb base reg
                when X"3" =>
                    v.fb_base := wbs_dat_i(31 downto 2);
                    
                -- reset reg
                when X"6" =>
                    v.resetme := '1';
                    
                when others =>
                    null;
            end case;
        else
            case wbs_adr_i(3 downto 0) is
                -- status reg
                when X"0" =>
                    v.wbs_dat_out       := ZERO32;
                    v.wbs_dat_out(0)    := not cmd_fifo_empty;
                    v.wbs_dat_out(1)    := r.switch_fb;
                    v.wbs_dat_out(2)    := to_sl(r.cmd_reads /= r.sync_cnt);
                    v.wbs_dat_out(3)    := cmd_fifo_full;
                    v.wbs_dat_out(4)    := cmd_fifo_empty;
                    
                -- addr reg
                when X"1" =>
                    v.wbs_dat_out(CMD_WDT-1 downto 0)  := r.cmd_cnt;
                    v.wbs_dat_out(31 downto CMD_WDT) := (others => '0');
                    
                -- sync cnt reg
                when X"2" =>
                    v.wbs_dat_out := r.cmd_reads(15 downto 0) & r.sync_cnt(15 downto 0);
                    
                -- capabilities reg
                when X"3" =>
                    v.wbs_dat_out := CAPABILITIES;
                    
                -- board name 0 reg
                when X"4" =>
                    v.wbs_dat_out := to_slv(BOARD_NAME(4)) & to_slv(BOARD_NAME(3)) & to_slv(BOARD_NAME(2)) & to_slv(BOARD_NAME(1));
                    
                -- board name 1 reg
                when X"5" =>
                    v.wbs_dat_out := to_slv(BOARD_NAME(8)) & to_slv(BOARD_NAME(7)) & to_slv(BOARD_NAME(6)) & to_slv(BOARD_NAME(5));
                    
                -- errors reg
                when X"6" =>
                    v.wbs_dat_out := r.errors_gpu;
                    
                -- debug regs
                when X"E" =>
                    v.wbs_dat_out := rast_debug;
                    
                when X"F" =>
                    v.wbs_dat_out := (
                        0 => input_to_vertex.axis_tvalid,   1 => vertex_to_input.axis_tready, 
                        2 => vertex_to_rast.axis_tvalid,    3 => rast_to_vertex.axis_tready,
                        4 => rast_to_cc.axis_tvalid,        5 => cc_to_rast.axis_tready,
                        6 => cc_to_texturing.axis_tvalid,   7 => texturing_to_cc.axis_tready,
                        8 => texturing_to_frag.axis_tvalid, 9 => frag_to_texturing.axis_tready,
                        10 => frag_to_final.axis_tvalid,    11 => final_to_frag.axis_tready,
                        
                        12 => tex_wb_mosi.wb_stb, 13 => frag_wb_mosi.wb_stb, 14 => fb_wb_mosi.wb_stb,
                        
                        others => '0'
                    );
                    v.wbs_dat_out(19 downto 16) := to_slv(wb_state_type'pos(r.state), 4);
                    
                when others =>
                    v.wbs_dat_out := (others => '1');
            end case;
        end if;
    end if;
    
    -- WB master
    case r.state is

        when IDLE =>
            -- wait for command from control WB register
            if (cmd_fifo_empty = '0') and (r.cmd_fifo_pop = '0') then
                v.state     := READ_CMDS;
                v.cmd_reads := r.cmd_reads + 1;
            elsif r.switch_fb = '1' then
                v.state     := SWITCH_FB_0;
                v.cache_inv(2)  := '1';
            end if;
            
        when SWITCH_FB_0 =>
            -- wait for cache invalidation to start
            v.cache_inv(2)  := '1';
            if (cache_inv_i(2)) then
                v.state := SWITCH_FB_1;
            end if;
            
        when SWITCH_FB_1 =>
            -- wait for FB cache invalidation to finish
            if (not cache_inv_i(2)) then
                v.state := SWITCH_FB_2;
            end if;
            
        when SWITCH_FB_2 =>
            v.switch_fb     := '0';
            v.wb_dat_out    := "0000" & GetCurFbAddr(r.fb_sel)(27 downto 2) & "00";
            v.wb_adr        := "00" & r.fb_base;
            v.fb_sel        := not r.fb_sel;   -- switch fb
            v.wb_stb        := '1';
            v.wb_we         := '1';
            v.state         := REQ;
            v.next_state    := IDLE;
            
        when READ_CMDS =>
            if (wb_cmd_ready_i = '1') then
                v.wb_we := '0';
                v.wb_stb   := '1';
                v.wb_adr := ("00" & (cur_cmd_base + r.cmd_cnt));
                v.next_state := PUSH_CMD;
                v.state := REQ;
            end if;
            
        when PUSH_CMD =>
            v.wb_cmd_data := r.wb_dat_in;
            v.wb_cmd_valid := '1';
            v.state := READ_CMDS;
            if v.cmd_cnt < cur_cmd_size-1 then
                v.cmd_cnt := r.cmd_cnt + 1;
            else
                v.cmd_cnt := (others => '0');
                v.cmd_fifo_pop := '1';
                v.state := IDLE;
            end if;
            
        when REQ =>
            if cmd_wb_ack_i = '1' then
                v.wb_stb   := '0';
                v.wb_we := '1';
                v.wb_dat_in := cmd_wb_dat_i;
                v.state := r.next_state;
            end if;
            
    end case;
    
    -- Final stream stage
    if frag_to_final.axis_tvalid then
        case r.stream_state is
            when STREAM_RCV_CMD =>
                if frag_to_final.axis_tdata = GPU_PIPE_CMD_SYNC then
                    v.sync_cnt := r.sync_cnt + 1;
                else
                    if ((frag_to_final.axis_tdata and GPU_PIPE_MASK_CMD) /= GPU_PIPE_MASK_CMD) then
                        -- synthesis translate_off
                        report_sync("Malformed command at the end of pipeline: " & to_hstring(frag_to_final.axis_tdata), failure);
                        -- synthesis translate_on
                        v.errors_gpu(0) := '1';   -- signal malformed command to errors reg
                    else
                        -- synthesis translate_off
                        report_sync("Unsupported command at the end of pipeline:  " & to_hstring(frag_to_final.axis_tdata), note);
                        -- synthesis translate_on
                        null;
                    end if;
                    
                    v.junk_size     := cmd_num_args(frag_to_final.axis_tdata);
                    if (v.junk_size /= 0) then
                        v.junk_cnt      := 1;
                        v.stream_state  := STREAM_RCV_JUNK;
                    end if;
                end if;
                
            when STREAM_RCV_JUNK =>
                if r.junk_cnt = r.junk_size then
                    v.stream_state :=  STREAM_RCV_CMD;
                else
                    v.junk_cnt := r.junk_cnt + 1;
                end if;
                
        end case;
    end if;
    
    rin <= v;
end process;

end arch;
