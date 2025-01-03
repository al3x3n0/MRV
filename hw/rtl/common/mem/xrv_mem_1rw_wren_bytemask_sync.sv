`include "xm_macro.svh"

module xrv_mem_1rw_wren_bytemask_sync #(
    parameter DATA_WIDTH_P = "inv",
    parameter DEPTH_P = "inv",
    parameter ADDR_WIDTH_LP = `XM_CLOG2(DEPTH_P),
    parameter WRITE_ENABLE_MASK_WIDTH_P = DATA_WIDTH_P >> 3
) (
    input  logic                                    clk_i,
    input  logic                                    rst_i,
    input  logic                                    do_rd_i,
    input  logic                                    do_wr_i,
    input  logic [ADDR_WIDTH_LP-1:0]                addr_i,
    input  logic [DATA_WIDTH_P-1:0]                 wr_data_i,
    input  logic [WRITE_ENABLE_MASK_WIDTH_P-1:0]    wr_mask_i,
    output logic [DATA_WIDTH_P-1:0]                 rd_data_o
  );

    for(genvar i=0; i < WRITE_ENABLE_MASK_WIDTH_P; i++) begin: bk
        xrv_mem_1rw_sync #( 
            .DATA_WIDTH_P   (8),
            .DEPTH_P        (DEPTH_P),
            .ADDR_WIDTH_LP  (ADDR_WIDTH_LP)
        ) mem_1rw_sync (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .wr_data_i      (wr_data_i[(i*8)+:8]),
            .addr_i         (addr_i),
            .do_rd_i        (do_rd_i),
            .do_wr_i        (do_wr_i & wr_mask_i[i]),
            .rd_data_o      (rd_data_o[(i*8)+:8])
        );
    end

endmodule
