library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.all;
use std.textio.all;

use work.gpu_pkg.all;
    
entity gpu_pipe_wb_tb is
    generic (
        EXTERNAL_WB     : boolean := False;
        VERBOSE         : boolean := False;
        INIT_FILENAME   : string  := "cube.hex"
    );
    port (
        ext_wbs_adr_i   : in  std_logic_vector(31 downto 0);
        ext_wbs_dat_i   : in  std_logic_vector(31 downto 0);
        ext_wbs_sel_i   : in  std_logic_vector(3 downto 0);
        ext_wbs_we_i    : in  std_logic;
        ext_wbs_stb_i   : in  std_logic;
        ext_wbs_cyc_i   : in  std_logic;
        ext_wbs_dat_o   : out std_logic_vector(31 downto 0);
        ext_wbs_ack_o   : out std_logic;
        
        mem_wbs_adr_i   : in  std_logic_vector(31 downto 0);
        mem_wbs_dat_i   : in  std_logic_vector(31 downto 0);
        mem_wbs_sel_i   : in  std_logic_vector(3 downto 0);
        mem_wbs_we_i    : in  std_logic;
        mem_wbs_stb_i   : in  std_logic;
        mem_wbs_cyc_i   : in  std_logic;
        mem_wbs_dat_o   : out std_logic_vector(31 downto 0);
        mem_wbs_ack_o   : out std_logic;
        
        fb_wbm_adr_o    : out std_logic_vector(31 downto 0);
        fb_wbm_dat_o    : out std_logic_vector(31 downto 0);
        fb_wbm_sel_o    : out std_logic_vector(3 downto 0);
        fb_wbm_we_o     : out std_logic;
        fb_wbm_stb_o    : out std_logic;
        fb_wbm_cyc_o    : out std_logic;
        fb_wbm_dat_i    : in  std_logic_vector(31 downto 0);
        fb_wbm_ack_i    : in  std_logic;
        
        cmd_wbm_adr_o   : out std_logic_vector(31 downto 0);
        cmd_wbm_dat_o   : out std_logic_vector(31 downto 0);
        cmd_wbm_sel_o   : out std_logic_vector(3 downto 0);
        cmd_wbm_we_o    : out std_logic;
        cmd_wbm_stb_o   : out std_logic;
        cmd_wbm_cyc_o   : out std_logic;
        cmd_wbm_dat_i   : in  std_logic_vector(31 downto 0);
        cmd_wbm_ack_i   : in  std_logic
    );
end;

architecture tb of gpu_pipe_wb_tb is

    constant FAST_CLEAR     : boolean := True;
    constant FIFO_WDT       : integer := 68;
    constant MEM_SIZE       : integer := 64*1024*1024;
    constant MEMORY_OFFSET  : integer := 16#40000000# / 4;
    constant FB_BASE_REG    : std_logic_vector(31 downto 0) := X"00003800";
    constant ZBUF_BASE_ADDR : std_logic_vector(31 downto 0) := X"40200000";
    constant ZBUF_OFFSET    : integer := to_uint(ZBUF_BASE_ADDR)/4 - MEMORY_OFFSET;
    constant SCREEN_WIDTH   : integer := 640;
    constant SCREEN_HEIGHT  : integer := 480;
    constant FB_SIZE        : integer := SCREEN_WIDTH*SCREEN_HEIGHT;
    constant CLK_PERIOD     : time := 10 ns;
    
    type memory_type is array (0 to (MEM_SIZE/4)-1) of std_logic_vector(31 downto 0);
    
    shared variable memory_init_size : integer;
    
    impure function init_ram(name : STRING) return memory_type is
        file ram_file       : text; -- open read_mode is name;
        variable status     : file_open_status;
        variable ram_line   : line;
        variable temp_word  : std_logic_vector(31 downto 0);
        variable temp_ram   : memory_type := (others => (others => '0'));
        variable inited     : integer;
    begin
        temp_ram := (others => (others => '1'));
        file_open(status, ram_file, name, read_mode);
        if status = open_ok then
            for i in 0 to MEM_SIZE/4-1 loop
                exit when endfile(ram_file);
                readline(ram_file, ram_line);
                hread(ram_line, temp_word);
                temp_ram(i) := temp_word;
                memory_init_size := i+1;
            end loop;
        elsif not EXTERNAL_WB then
            report "Could not open init file " & name;
        end if;

        return temp_ram;
    end function;

    signal clk      : std_logic := '0';
    signal gpu_clk  : std_logic := '0';
    signal rst      : std_logic := '1';
    signal resetme  : std_logic;

    signal wb_adr4      : std_logic_vector(31 downto 0);
    
    signal wbs_dat_in   : std_logic_vector(31 downto 0);
    signal wbs_dat_out  : std_logic_vector(31 downto 0);
    signal wbs_adr      : std_logic_vector(31 downto 0);
    signal wbs_stb      : std_logic;
    signal wbs_we       : std_logic;
    signal wbs_ack      : std_logic;
    
    signal cmd_wb_mosi  : wishbone_mosi_type;
    signal cmd_wb_miso  : wishbone_miso_type;
    signal tex_wb_mosi  : wishbone_mosi_type;
    signal tex_wb_miso  : wishbone_miso_type;
    signal frag_wb_mosi : wishbone_mosi_type;
    signal frag_wb_miso : wishbone_miso_type;
    signal fb_wb_mosi   : wishbone_mosi_type;
    signal fb_wb_miso   : wishbone_miso_type;
    
    signal fifo_in      : std_logic_vector(FIFO_WDT-1 downto 0);
    signal fifo_out     : std_logic_vector(FIFO_WDT-1 downto 0);
    signal fifo_push    : std_logic;
    signal fifo_pop     : std_logic;
    signal fifo_full    : std_logic;
    signal fifo_empty   : std_logic;
    
    signal wb_cmd_dat       : std_logic_vector(31 downto 0);
    signal wb_cmd_valid     : std_logic;
    signal wb_cmd_ready     : std_logic;
    signal axis_cmd_data    : std_logic_vector(31 downto 0);
    signal axis_cmd_valid   : std_logic;
    signal axis_cmd_ready   : std_logic;
    signal cmd_fifo_full    : std_logic;
    signal cmd_fifo_empty   : std_logic;
    
    signal axis_rast_valid  : std_logic;
    signal axis_rast_data   : std_logic_vector(31 downto 0);
    signal axis_rast_ready  : std_logic;
    signal axis_tex_valid   : std_logic;
    signal axis_tex_data    : std_logic_vector(31 downto 0);
    signal axis_tex_ready   : std_logic;
    
    signal cache_inv        : std_logic_vector(2 downto 0);
    
    signal switch_cnt       : integer := 0;
    
    signal cocotb_test_complete : std_logic := '0';
    
begin

gpu_pipe : entity work.gpu_pipe_wb
    generic map (
        BOARD_NAME      => "HDL sim ",
        CAPABILITIES    => X"00000000",
        FB_BASE_REG     => FB_BASE_REG,
        SCREEN_WIDTH    => SCREEN_WIDTH,
        SCREEN_HEIGHT   => SCREEN_HEIGHT,
        ZBUF_BASE_ADDR  => ZBUF_BASE_ADDR,
        FAST_CLEAR      => FAST_CLEAR
    )
    port map (
        clk_i           => clk,
        gpu_clk_i       => gpu_clk,
        rst_i           => rst,
        gpu_rst_i       => rst,
        resetme_o       => resetme,
        
        cmd_wb_adr_o    => cmd_wb_mosi.wb_adr, 
        cmd_wb_dat_o    => cmd_wb_mosi.wb_dato,
        cmd_wb_sel_o    => cmd_wb_mosi.wb_sel,
        cmd_wb_we_o     => cmd_wb_mosi.wb_we,
        cmd_wb_stb_o    => cmd_wb_mosi.wb_stb,
        cmd_wb_cyc_o    => cmd_wb_mosi.wb_cyc,
        cmd_wb_dat_i    => cmd_wb_miso.wb_dati,
        cmd_wb_ack_i    => cmd_wb_miso.wb_ack,
        
        tex_wb_adr_o    => tex_wb_mosi.wb_adr, 
        tex_wb_dat_o    => tex_wb_mosi.wb_dato,
        tex_wb_sel_o    => tex_wb_mosi.wb_sel,
        tex_wb_we_o     => tex_wb_mosi.wb_we,
        tex_wb_stb_o    => tex_wb_mosi.wb_stb,
        tex_wb_cyc_o    => tex_wb_mosi.wb_cyc,
        tex_wb_dat_i    => tex_wb_miso.wb_dati,
        tex_wb_ack_i    => tex_wb_miso.wb_ack,
        
        frag_wb_adr_o   => frag_wb_mosi.wb_adr, 
        frag_wb_dat_o   => frag_wb_mosi.wb_dato,
        frag_wb_sel_o   => frag_wb_mosi.wb_sel,
        frag_wb_we_o    => frag_wb_mosi.wb_we,
        frag_wb_stb_o   => frag_wb_mosi.wb_stb,
        frag_wb_cyc_o   => frag_wb_mosi.wb_cyc,
        frag_wb_dat_i   => frag_wb_miso.wb_dati,
        frag_wb_ack_i   => frag_wb_miso.wb_ack,
                        
        fb_wb_adr_o     => fb_wb_mosi.wb_adr, 
        fb_wb_dat_o     => fb_wb_mosi.wb_dato,
        fb_wb_sel_o     => fb_wb_mosi.wb_sel,
        fb_wb_we_o      => fb_wb_mosi.wb_we,
        fb_wb_stb_o     => fb_wb_mosi.wb_stb,
        fb_wb_cyc_o     => fb_wb_mosi.wb_cyc,
        fb_wb_dat_i     => fb_wb_miso.wb_dati,
        fb_wb_ack_i     => fb_wb_miso.wb_ack,
        
        wbs_adr_i       => wbs_adr,
        wbs_dat_i       => wbs_dat_in,
        wbs_sel_i       => "1111",
        wbs_we_i        => wbs_we,
        wbs_stb_i       => wbs_stb,
        wbs_cyc_i       => wbs_stb,
        wbs_dat_o       => wbs_dat_out,
        wbs_ack_o       => wbs_ack,
        
        wb_cmd_data_o       => wb_cmd_dat,
        wb_cmd_valid_o      => wb_cmd_valid, 
        wb_cmd_ready_i      => wb_cmd_ready,
        axis_cmd_data_i     => axis_cmd_data,
        axis_cmd_valid_i    => axis_cmd_valid,
        axis_cmd_ready_o    => axis_cmd_ready,
        
        axis_rast_valid_o   => axis_rast_valid,
        axis_rast_data_o    => axis_rast_data,
        axis_rast_ready_i   => axis_rast_ready,
        
        axis_tex_valid_i    => axis_tex_valid,
        axis_tex_data_i     => axis_tex_data,
        axis_tex_ready_o    => axis_tex_ready,
        
        cache_inv_o         => cache_inv,   -- shortcut as no cache
        cache_inv_i         => cache_inv
    );

clk <= not clk after CLK_PERIOD/2;
gpu_clk <= clk;
rst <= resetme after 100 ns;
wb_adr4 <= cmd_wb_mosi.wb_adr(29 downto 0) & "00";

wb_cmd_ready <= not cmd_fifo_full;
axis_cmd_valid <= not cmd_fifo_empty;

cmd_fifo : entity work.afull_fifo
    generic map (
        DEPTH           => 5,
        WDT             => 32
    )
    port map (
        clk_i   => clk,
        rst_i   => rst,
        dat_i   => wb_cmd_dat,
        dat_o   => axis_cmd_data,
        push_i  => wb_cmd_valid, 
        pop_i   => axis_cmd_ready,
        full_o  => cmd_fifo_full,
        empty_o => cmd_fifo_empty
    );

cc_fifo : entity work.stream_fifo_wrapper
    generic map (
        DEPTH   => 5,
        LAST    => 0
    )
    port map (
        clk_i           => clk,
        rst_i           => rst,
        s_axis_tdata    => axis_rast_data,
        s_axis_tvalid   => axis_rast_valid,
        s_axis_tlast    => '0',
        s_axis_tready   => axis_rast_ready,
        
        m_axis_tdata    => axis_tex_data,
        m_axis_tvalid   => axis_tex_valid,
        m_axis_tready   => axis_tex_ready
    );

TB_REG_DRIVER : if not EXTERNAL_WB generate

-- WB slave driver process
process(clk)
    type wbs_state_type is (WBS_IDLE, WBS_WRITE_SIZE, WBS_TRIGGER, WBS_WAIT, WBS_CHECK, WBS_END);
    variable state              : wbs_state_type := WBS_IDLE;
    variable wait_cnt           : integer;
begin
    if Rising_edge(clk) then
        case state is
            when WBS_IDLE =>
                wbs_stb <= '0';
                wbs_we <= '1';
                if rst = '1' then
                    null;
                else
                    state := WBS_WRITE_SIZE;
                    wait_cnt := 0;
                end if;
                
            when WBS_WRITE_SIZE =>
                wbs_stb <= '1';
                wbs_adr <= X"08000001"; -- 0x20000004
                wbs_dat_in <= std_logic_vector(to_unsigned(memory_init_size, 32));
                state := WBS_TRIGGER;
                
            when WBS_TRIGGER =>
                wbs_stb <= '1';
                wbs_adr <= X"08000000"; -- 0x20000000
                wbs_dat_in(3 downto 0) <= "1111";
                wbs_dat_in(31 downto 4) <= (others => '0');
                state := WBS_WAIT;
                
            when WBS_WAIT =>
                wbs_stb <= '0';
                if wait_cnt = 100 then
                    wait_cnt := 0;
                    state := WBS_CHECK;
                    
                    wbs_stb <= '1';
                    wbs_we <= '0';
                    wbs_adr <= X"08000000"; -- 0x20000000
                else
                    wait_cnt := wait_cnt + 1;
                end if;
                
            when WBS_CHECK =>
                wbs_stb <= '0';
                if wbs_ack = '1' then
                    if wbs_dat_out(1) = '0' then 
                        state := WBS_IDLE;
                    else
                        state := WBS_WAIT;
                    end if;
                end if;
                
            when WBS_END =>
                wbs_stb <= '0';
        end case;
    end if;
end process;

else generate

    -- connect register WB bus to cocotb
    wbs_adr <= "00" & ext_wbs_adr_i(31 downto 2);
    wbs_dat_in <= ext_wbs_dat_i; 
    wbs_we  <= ext_wbs_we_i;  
    wbs_stb <= ext_wbs_stb_i; 
    ext_wbs_dat_o <= wbs_dat_out;
    ext_wbs_ack_o <= wbs_ack; 
    
    -- memory WB bus from cocotb
    mem_wbs_ack_o <= '1';
    mem_wbs_dat_o <= (others => '1');   -- !! no read from mem
    
    -- Cmd & fb WB buses to cocotb (only writes)
    fb_wbm_we_o <= '1';
    fb_wbm_sel_o <= fb_wb_mosi.wb_sel;
    fb_wbm_dat_o <= fb_wb_mosi.wb_dato;
    fb_wbm_adr_o <= fb_wb_mosi.wb_adr(29 downto 0) & "00";
    fb_wbm_stb_o <= fb_wb_mosi.wb_stb and fb_wb_mosi.wb_we;
    fb_wbm_cyc_o <= fb_wb_mosi.wb_cyc and fb_wb_mosi.wb_we;
    
    cmd_wbm_we_o <= '1';
    cmd_wbm_sel_o <= cmd_wb_mosi.wb_sel;
    cmd_wbm_dat_o <= cmd_wb_mosi.wb_dato;
    cmd_wbm_adr_o <= cmd_wb_mosi.wb_adr(29 downto 0) & "00";
    cmd_wbm_stb_o <= cmd_wb_mosi.wb_stb and fb_wb_mosi.wb_we;
    cmd_wbm_cyc_o <= cmd_wb_mosi.wb_cyc and fb_wb_mosi.wb_we;

end generate;


-- WB master monitor process
process(clk)
    variable memory         : memory_type := init_ram(INIT_FILENAME);
    variable off            : integer;
    variable first          : boolean := True;
    constant FB_SWITCHES_TILL_FINISH    : integer := 0;
    variable tex_ack_cnt    : integer := 0;
    variable tex_ack_len    : integer := 0;
    variable ack_cnt        : integer := 0;
    variable ack_len        : integer := 0;
    variable frag_ack_cnt   : integer := 0;
    variable frag_ack_len   : integer := 0;
    variable fb_ack_cnt     : integer := 0;
    variable fb_ack_len     : integer := 0;
    
    constant FAST_CLEAR_ADDR : vec32 := max_vec(32);
begin
    if Rising_edge(clk) then
    
        cmd_wb_miso.wb_ack <= '0';
        
        if cmd_wb_mosi.wb_stb and cmd_wb_mosi.wb_cyc then
            --wb_ack <= '1';
            if ack_cnt >= ack_len then
                cmd_wb_miso.wb_ack <= '1';
                ack_cnt := 0;
                if ack_len >= 0 then
                    ack_len := 0;
                else
                    ack_len := ack_len + 7;
                end if;
            else
                ack_cnt := ack_cnt + 1;
            end if;
            
            off := to_integer(unsigned(cmd_wb_mosi.wb_adr)) - MEMORY_OFFSET;
            
            if cmd_wb_mosi.wb_we = '0' then
                cmd_wb_miso.wb_dati <= memory(off);
            end if;
            
            if cmd_wb_miso.wb_ack = '1' then
                if cmd_wb_mosi.wb_we then
                    if VERBOSE then
                        report "WB write: " & to_hstring(wb_adr4) & " " & to_hstring(cmd_wb_mosi.wb_dato);
                    end if;
                    
                    if (wb_adr4 = FB_BASE_REG) then
                        if VERBOSE then
                            report "FB switch";
                        end if;
                        if not EXTERNAL_WB and (switch_cnt = FB_SWITCHES_TILL_FINISH) then
                            cocotb_test_complete <= '1';
                        end if;
                        switch_cnt <= switch_cnt + 1;
                        --if NO_BLANK then
                            --memory := (others => (others => '1'));
                        --end if;
                    elsif (wb_adr4 > X"40000000") then
                        memory(off) := cmd_wb_mosi.wb_dato;
                    end if;
                elsif VERBOSE then
                    report "WB read : " & to_hstring(wb_adr4) & " " & to_hstring(memory(off));
                end if;
            end if;
        end if;
        
        if EXTERNAL_WB and ((mem_wbs_stb_i and mem_wbs_cyc_i and mem_wbs_we_i) = '1') then
            memory(to_integer(unsigned(mem_wbs_adr_i(31 downto 2))) - MEMORY_OFFSET) := mem_wbs_dat_i;
        end if; 
        
        tex_wb_miso.wb_ack <= '0';
        
        if tex_wb_mosi.wb_stb and tex_wb_mosi.wb_cyc then
            if tex_ack_cnt >= tex_ack_len then
                tex_wb_miso.wb_ack <= '1';
                tex_ack_cnt := 0;
                if tex_ack_len >= 0 then
                    tex_ack_len := 0;
                else
                    tex_ack_len := tex_ack_len + 3;
                end if;
            else
                tex_ack_cnt := tex_ack_cnt + 1;
            end if;
            off := to_integer(unsigned(tex_wb_mosi.wb_adr)) - MEMORY_OFFSET;   
            
            if tex_wb_mosi.wb_we = '0' then
                tex_wb_miso.wb_dati <= memory(off);
            end if;
            
            if tex_wb_miso.wb_ack = '1' then
                if tex_wb_mosi.wb_we then
                    memory(off) := tex_wb_mosi.wb_dato;
                end if;
            end if;
        end if;
        
        frag_wb_miso.wb_ack <= '0';
        
        if frag_wb_mosi.wb_stb and frag_wb_mosi.wb_cyc then
            if frag_ack_cnt >= frag_ack_len then
                frag_wb_miso.wb_ack <= '1';
                frag_ack_cnt := 0;
                if frag_ack_len >= 3 then
                    frag_ack_len := 0;
                else
                    frag_ack_len := frag_ack_len + 1;
                end if;
            else
                frag_ack_cnt := frag_ack_cnt + 1;
            end if;
            
            if frag_wb_mosi.wb_adr /= FAST_CLEAR_ADDR then
                off := to_integer(unsigned(frag_wb_mosi.wb_adr)) - MEMORY_OFFSET;  
            end if;
            
            if frag_wb_mosi.wb_we = '0' then
                frag_wb_miso.wb_dati <= memory(off);
            end if;
            
            if frag_wb_miso.wb_ack = '1' then
                if frag_wb_mosi.wb_we then
                    if FAST_CLEAR and (frag_wb_mosi.wb_adr = FAST_CLEAR_ADDR) then
                        for i in ZBUF_OFFSET to ZBUF_OFFSET + FB_SIZE loop
                            memory(i) := X"00FFFFFF";  -- fast clear Z-buf
                        end loop;
                    else
                        memory(off) := frag_wb_mosi.wb_dato;
                    end if;
                end if;
            end if;
        end if;
        
        fb_wb_miso.wb_ack <= '0';
        
        if fb_wb_mosi.wb_stb and fb_wb_mosi.wb_cyc then
            if fb_ack_cnt >= fb_ack_len then
                fb_wb_miso.wb_ack <= '1';
                fb_ack_cnt := 0;
                if fb_ack_len >= 0 then
                    fb_ack_len := 0;
                else
                    fb_ack_len := fb_ack_len + 1;
                end if;
            else
                fb_ack_cnt := fb_ack_cnt + 1;
            end if;
            if fb_wb_mosi.wb_adr /= FAST_CLEAR_ADDR then
                off := to_integer(unsigned(fb_wb_mosi.wb_adr)) - MEMORY_OFFSET;  
                
                if fb_wb_mosi.wb_we = '0' then
                    fb_wb_miso.wb_dati <= memory(off);
                end if;
                
                if fb_wb_miso.wb_ack then
                    if fb_wb_mosi.wb_we then
                        memory(off) := fb_wb_mosi.wb_dato;
                    end if;
                end if;
            end if;
        end if;
        
    end if;
end process;


-- Termination process in case if running without cocotb_empty.py testbench
process
begin
    wait on cocotb_test_complete;
    wait for 10 ns; -- give some time to cocotb
    assert cocotb_test_complete = '1' report "Test failed!" severity failure;
    finish;
end process;


end tb;

