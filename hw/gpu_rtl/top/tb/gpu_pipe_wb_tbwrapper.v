// Small simulation wrapper to generate clocks and rename some signals.
// Clock generation in HDL is faster than in cocotb.

`timescale 1 ns/1 ps

module gpu_pipe_wb_tbwrapper
    #( 
        parameter CLK_PERIOD_NS       = 8,
        parameter GPU_CLK_PERIOD_NS   = 10
    )
    (
        input  rst_i,
        input  gpu_rst_i,
        output resetme_o,
               
        output axis_wb_tvalid,
        output [31:0] axis_wb_tdata,
        input  axis_wb_tready,
               
        input  axis_cmd_tvalid,
        input  [31:0] axis_cmd_tdata,
        output axis_cmd_tready,
               
        output axis_rast_tvalid,
        output [31:0] axis_rast_tdata,
        input  axis_rast_tready,
               
        input  axis_tex_tvalid,
        input  [31:0] axis_tex_tdata,
        output axis_tex_tready,
               
        output [31:0] cmd_wb_adr_o,
        output [31:0] cmd_wb_dat_o,
        output [3:0] cmd_wb_sel_o,
        output cmd_wb_we_o,
        output cmd_wb_stb_o,
        output cmd_wb_cyc_o,
        input  [31:0] cmd_wb_dat_i,
        input  cmd_wb_ack_i,
               
        output [31:0] tex_wb_adr_o,
        output [31:0] tex_wb_dat_o,
        output [3:0] tex_wb_sel_o,
        output tex_wb_we_o,
        output tex_wb_stb_o,
        output tex_wb_cyc_o,
        input  [31:0] tex_wb_dat_i,
        input  tex_wb_ack_i,
               
        output [31:0] frag_wb_adr_o,
        output [31:0] frag_wb_dat_o,
        output [3:0] frag_wb_sel_o,
        output frag_wb_we_o,
        output frag_wb_stb_o,
        output frag_wb_cyc_o,
        input  [31:0] frag_wb_dat_i,
        input  frag_wb_ack_i,
               
        output [31:0] fb_wb_adr_o,
        output [31:0] fb_wb_dat_o,
        output [3:0] fb_wb_sel_o,
        output fb_wb_we_o,
        output fb_wb_stb_o,
        output fb_wb_cyc_o,
        input  [31:0] fb_wb_dat_i,
        input  fb_wb_ack_i,
               
        input  [31:0] wbs_adr_i,
        input  [31:0] wbs_dat_i,
        input  [3:0] wbs_sel_i,
        input  wbs_we_i,
        input  wbs_stb_i,
        input  wbs_cyc_i,
        output [31:0] wbs_dat_o,
        output wbs_ack_o,
               
        output [2:0] cache_inv_o,
        input  [2:0] cache_inv_i
    );


reg clk     = 1'b0;
reg gpu_clk = 1'b0;

`ifndef NO_VERILOG_CLK_GEN
// break Verilator for some reason :(
always #(CLK_PERIOD_NS/2) clk = ~clk;
always #(GPU_CLK_PERIOD_NS/2) gpu_clk = ~gpu_clk;
`endif

gpu_pipe_wb gpu
    (
        .clk_i(clk),
        .gpu_clk_i(gpu_clk),
        .rst_i(rst_i),
        .gpu_rst_i(gpu_rst_i),
        .resetme_o(resetme_o),
        
        .axis_wb_valid_o(axis_wb_tvalid),
        .axis_wb_data_o(axis_wb_tdata),
        .axis_wb_ready_i(axis_wb_tready),
        
        .axis_cmd_valid_i(axis_cmd_tvalid),
        .axis_cmd_data_i(axis_cmd_tdata),
        .axis_cmd_ready_o(axis_cmd_tready),
        
        .axis_rast_valid_o(axis_rast_tvalid),
        .axis_rast_data_o(axis_rast_tdata),
        .axis_rast_ready_i(axis_rast_tready),
        
        .axis_tex_valid_i(axis_tex_tvalid),
        .axis_tex_data_i(axis_tex_tdata),
        .axis_tex_ready_o(axis_tex_tready),
        
        .cmd_wb_adr_o(cmd_wb_adr_o),
        .cmd_wb_dat_o(cmd_wb_dat_o),
        .cmd_wb_sel_o(cmd_wb_sel_o),
        .cmd_wb_we_o(cmd_wb_we_o),
        .cmd_wb_stb_o(cmd_wb_stb_o),
        .cmd_wb_cyc_o(cmd_wb_cyc_o),
        .cmd_wb_dat_i(cmd_wb_dat_i),
        .cmd_wb_ack_i(cmd_wb_ack_i),
        
        .tex_wb_adr_o(tex_wb_adr_o), 
        .tex_wb_dat_o(tex_wb_dat_o),  
        .tex_wb_sel_o(tex_wb_sel_o),  
        .tex_wb_we_o(tex_wb_we_o),   
        .tex_wb_stb_o(tex_wb_stb_o),  
        .tex_wb_cyc_o(tex_wb_cyc_o),  
        .tex_wb_dat_i(tex_wb_dat_i),  
        .tex_wb_ack_i(tex_wb_ack_i),  
        
        .frag_wb_adr_o(frag_wb_adr_o), 
        .frag_wb_dat_o(frag_wb_dat_o), 
        .frag_wb_sel_o(frag_wb_sel_o), 
        .frag_wb_we_o(frag_wb_we_o),  
        .frag_wb_stb_o(frag_wb_stb_o), 
        .frag_wb_cyc_o(frag_wb_cyc_o), 
        .frag_wb_dat_i(frag_wb_dat_i), 
        .frag_wb_ack_i(frag_wb_ack_i), 
        
        .fb_wb_adr_o(fb_wb_adr_o),   
        .fb_wb_dat_o(fb_wb_dat_o),   
        .fb_wb_sel_o(fb_wb_sel_o),   
        .fb_wb_we_o(fb_wb_we_o),    
        .fb_wb_stb_o(fb_wb_stb_o),   
        .fb_wb_cyc_o(fb_wb_cyc_o),   
        .fb_wb_dat_i(fb_wb_dat_i),   
        .fb_wb_ack_i(fb_wb_ack_i),   
        
        .wbs_adr_i(wbs_adr_i),     
        .wbs_dat_i(wbs_dat_i),     
        .wbs_sel_i(wbs_sel_i),     
        .wbs_we_i(wbs_we_i ),     
        .wbs_stb_i(wbs_stb_i),     
        .wbs_cyc_i(wbs_cyc_i),     
        .wbs_dat_o(wbs_dat_o),     
        .wbs_ack_o(wbs_ack_o),     
        
        .cache_inv_o(cache_inv_o),   
        .cache_inv_i(cache_inv_i)
    );

`ifdef WAVE
initial begin $dumpfile("wave-verilog.fst"); $dumpvars(0); end
`endif

endmodule

