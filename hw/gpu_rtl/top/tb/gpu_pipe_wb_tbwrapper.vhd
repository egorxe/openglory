-- Small simulation wrapper to generate clocks and rename some signals.
-- Clock generation in HDL is faster than in cocotb.

library ieee;
use ieee.std_logic_1164.all;

use work.gpu_pkg.all;
    
entity gpu_pipe_wb_tbwrapper is
    generic (
        CLK_PERIOD_NS       : integer := 8;
        GPU_CLK_PERIOD_NS   : integer := 10
    );
    port (
        rst_i               : in  std_logic;
        gpu_rst_i           : in  std_logic;
        resetme_o           : out std_logic;
        
        axis_wb_tvalid      : out std_logic;
        axis_wb_tdata       : out vec32;
        axis_wb_tready      : in  std_logic;
        
        axis_cmd_tvalid     : in  std_logic;
        axis_cmd_tdata      : in  vec32;
        axis_cmd_tready     : out std_logic;
        
        axis_rast_tvalid    : out std_logic;
        axis_rast_tdata     : out vec32;
        axis_rast_tready    : in  std_logic;
        
        axis_tex_tvalid     : in  std_logic;
        axis_tex_tdata      : in  vec32;
        axis_tex_tready     : out std_logic;
        
        cmd_wb_adr_o        : out std_logic_vector(WB_ADDR_WIDTH-1 downto 0);
        cmd_wb_dat_o        : out std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        cmd_wb_sel_o        : out std_logic_vector((WB_DATA_WIDTH/8)-1 downto 0);
        cmd_wb_we_o         : out std_logic;
        cmd_wb_stb_o        : out std_logic;
        cmd_wb_cyc_o        : out std_logic;
        cmd_wb_dat_i        : in  std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        cmd_wb_ack_i        : in  std_logic;
            
        tex_wb_adr_o        : out std_logic_vector(WB_ADDR_WIDTH-1 downto 0);
        tex_wb_dat_o        : out std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        tex_wb_sel_o        : out std_logic_vector((WB_DATA_WIDTH/8)-1 downto 0);
        tex_wb_we_o         : out std_logic;
        tex_wb_stb_o        : out std_logic;
        tex_wb_cyc_o        : out std_logic;
        tex_wb_dat_i        : in  std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        tex_wb_ack_i        : in  std_logic;
            
        frag_wb_adr_o       : out std_logic_vector(WB_ADDR_WIDTH-1 downto 0);
        frag_wb_dat_o       : out std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        frag_wb_sel_o       : out std_logic_vector((WB_DATA_WIDTH/8)-1 downto 0);
        frag_wb_we_o        : out std_logic;
        frag_wb_stb_o       : out std_logic;
        frag_wb_cyc_o       : out std_logic;
        frag_wb_dat_i       : in  std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        frag_wb_ack_i       : in  std_logic;
            
        fb_wb_adr_o         : out std_logic_vector(WB_ADDR_WIDTH-1 downto 0);
        fb_wb_dat_o         : out std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        fb_wb_sel_o         : out std_logic_vector((WB_DATA_WIDTH/8)-1 downto 0);
        fb_wb_we_o          : out std_logic;
        fb_wb_stb_o         : out std_logic;
        fb_wb_cyc_o         : out std_logic;
        fb_wb_dat_i         : in  std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        fb_wb_ack_i         : in  std_logic;
            
        wbs_adr_i           : in  std_logic_vector(WB_ADDR_WIDTH-1 downto 0);
        wbs_dat_i           : in  std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        wbs_sel_i           : in  std_logic_vector((WB_DATA_WIDTH/8)-1 downto 0);
        wbs_we_i            : in  std_logic;
        wbs_stb_i           : in  std_logic;
        wbs_cyc_i           : in  std_logic;
        wbs_dat_o           : out std_logic_vector(WB_DATA_WIDTH-1 downto 0);
        wbs_ack_o           : out std_logic;
            
        cache_inv_o         : out std_logic_vector(2 downto 0);
        cache_inv_i         : in  std_logic_vector(2 downto 0)
    );
end;

architecture tb of gpu_pipe_wb_tbwrapper is

    signal clk              : std_logic := '0';
    signal gpu_clk          : std_logic := '0';

begin

clk <= not clk after CLK_PERIOD_NS * 0.5 ns;
gpu_clk <= not gpu_clk after GPU_CLK_PERIOD_NS * 0.5 ns;

gpu : entity work.gpu_pipe_wb
    port map (
        clk_i               => clk,
        gpu_clk_i           => gpu_clk,
        rst_i               => rst_i,
        gpu_rst_i           => gpu_rst_i,
        resetme_o           => resetme_o,
        
        axis_wb_valid_o     => axis_wb_tvalid,
        axis_wb_data_o      => axis_wb_tdata,
        axis_wb_ready_i     => axis_wb_tready,
                            
        axis_cmd_valid_i    => axis_cmd_tvalid,
        axis_cmd_data_i     => axis_cmd_tdata,
        axis_cmd_ready_o    => axis_cmd_tready,
                            
        axis_rast_valid_o   => axis_rast_tvalid,
        axis_rast_data_o    => axis_rast_tdata,
        axis_rast_ready_i   => axis_rast_tready,
                            
        axis_tex_valid_i    => axis_tex_tvalid,
        axis_tex_data_i     => axis_tex_tdata,
        axis_tex_ready_o    => axis_tex_tready,
        
        cmd_wb_adr_o        => cmd_wb_adr_o,
        cmd_wb_dat_o        => cmd_wb_dat_o,
        cmd_wb_sel_o        => cmd_wb_sel_o,
        cmd_wb_we_o         => cmd_wb_we_o,
        cmd_wb_stb_o        => cmd_wb_stb_o,
        cmd_wb_cyc_o        => cmd_wb_cyc_o,
        cmd_wb_dat_i        => cmd_wb_dat_i,
        cmd_wb_ack_i        => cmd_wb_ack_i,
            
        tex_wb_adr_o        => tex_wb_adr_o, 
        tex_wb_dat_o        => tex_wb_dat_o,  
        tex_wb_sel_o        => tex_wb_sel_o,  
        tex_wb_we_o         => tex_wb_we_o,   
        tex_wb_stb_o        => tex_wb_stb_o,  
        tex_wb_cyc_o        => tex_wb_cyc_o,  
        tex_wb_dat_i        => tex_wb_dat_i,  
        tex_wb_ack_i        => tex_wb_ack_i,  
                            
        frag_wb_adr_o       => frag_wb_adr_o, 
        frag_wb_dat_o       => frag_wb_dat_o, 
        frag_wb_sel_o       => frag_wb_sel_o, 
        frag_wb_we_o        => frag_wb_we_o,  
        frag_wb_stb_o       => frag_wb_stb_o, 
        frag_wb_cyc_o       => frag_wb_cyc_o, 
        frag_wb_dat_i       => frag_wb_dat_i, 
        frag_wb_ack_i       => frag_wb_ack_i, 
                                            
        fb_wb_adr_o         => fb_wb_adr_o,   
        fb_wb_dat_o         => fb_wb_dat_o,   
        fb_wb_sel_o         => fb_wb_sel_o,   
        fb_wb_we_o          => fb_wb_we_o,    
        fb_wb_stb_o         => fb_wb_stb_o,   
        fb_wb_cyc_o         => fb_wb_cyc_o,   
        fb_wb_dat_i         => fb_wb_dat_i,   
        fb_wb_ack_i         => fb_wb_ack_i,   
                            
        wbs_adr_i           => wbs_adr_i,     
        wbs_dat_i           => wbs_dat_i,     
        wbs_sel_i           => wbs_sel_i,     
        wbs_we_i            => wbs_we_i ,     
        wbs_stb_i           => wbs_stb_i,     
        wbs_cyc_i           => wbs_cyc_i,     
        wbs_dat_o           => wbs_dat_o,     
        wbs_ack_o           => wbs_ack_o,     
            
        cache_inv_o         => cache_inv_o,   
        cache_inv_i         => cache_inv_i
    );

end tb;

