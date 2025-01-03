module xrv1_mul
#(
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = "inv"
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                             clk_i,
    input logic                             rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                             mul_req_i,
    output logic                            mul_rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [1:0]                       mul_opc_i,
    input logic [31:0]                      mul_src0_i,
    input logic [31:0]                      mul_src1_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                            mul_res_vld_o,
    output logic [31:0]                     mul_res_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [ITAG_WIDTH_P-1:0]          mul_itag_i,
    output logic [ITAG_WIDTH_P-1:0]         mul_itag_o
    ////////////////////////////////////////////////////////////////////////////////
);

    assign mul_res_vld_o = 1'b0;

endmodule;