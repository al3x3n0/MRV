`include "xm_macro.svh"


module xrv_mem_1rw_wren_bitmask_sync
#(
    parameter DATA_WIDTH_P = "inv",
    parameter DEPTH_P = "inv",
    parameter ADDR_WIDTH_LP = `XM_CLOG2(DEPTH_P)
) (
    input  logic                        clk_i,
    input  logic                        rst_i,
    input  logic [ADDR_WIDTH_LP-1:0]    addr_i,
    input  logic                        do_rd_i,
    input  logic                        do_wr_i,
    input  logic [DATA_WIDTH_P-1:0]     wr_mask_i,
    input  logic [DATA_WIDTH_P-1:0]     wr_data_i,
    output logic [DATA_WIDTH_P-1:0]     rd_data_o
);

   `XM_UNUSED_VAR(rst_i);

    logic [ADDR_WIDTH_LP-1:0] addr_r;
    logic [DATA_WIDTH_P-1:0] mem [DEPTH_P-1:0];   
    logic [ADDR_WIDTH_LP-1:0] addr_li = (DEPTH_P>1) ? addr_i:'0;
    
    logic [DATA_WIDTH_P-1:0] data_n;
    for (genvar i = 0; i < DATA_WIDTH_P; i++) begin : rof1
        assign data_n[i] = wr_mask_i[i] ? wr_data_i[i] : mem[addr_li][i];
    end // rof1

    always_ff @(posedge clk_i) begin
        if (do_rd_i) begin
            addr_r <= addr_li;
        end
        if (do_wr_i) begin
            mem[addr_li] <= data_n;
        end
    end
    assign rd_data_o = mem[addr_r];
 
endmodule

