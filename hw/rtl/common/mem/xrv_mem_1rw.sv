`include "xm_macro.svh"

module xrv_mem_1rw  #(
    parameter DATA_WIDTH_P = "inv",
    parameter DEPTH_P = "inv",
    parameter ADDR_WIDTH_LP = `XM_CLOG2(DEPTH_P)
) (
    input  logic                        clk_i,
    input  logic                        rst_i,
    input  logic [ADDR_WIDTH_LP-1:0]    addr_i,
    input  logic                        do_wr_i,
    input  logic [DATA_WIDTH_P-1:0]     wr_data_i,
    output logic [DATA_WIDTH_P-1:0]     rd_data_o
);
    `XM_UNUSED_VAR(rst_i);

    if (DATA_WIDTH_P == 0 || DEPTH_P == 0) begin: z
        `XM_UNUSED_VAR(clk_i);
        `XM_UNUSED_VAR(do_wr_i);
        `XM_UNUSED_VAR(addr_i);
        `XM_UNUSED_VAR(wr_data_i);
        assign rd_data_o = '0;
    end
    else begin: nz

        logic [DATA_WIDTH_P-1:0] mem [DEPTH_P-1:0];
        logic [ADDR_WIDTH_LP-1:0] addr_li = (DEPTH_P > 0) ? addr_i : '0;

        always_ff @ (posedge clk_i) begin 
            if (do_wr_i) begin
                mem[addr_li] <= wr_data_i;
            end
        end
        assign rd_data_o = mem[addr_i];
    end // non_zero_width

endmodule