module xrv1_div
#(
    parameter data_width_p = 32,
    parameter ITAG_WIDTH_P = "inv"
)(
    ////////////////////////////////////////////////////////////////////////////////
    input logic                         clk_i,
    input logic                         rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                         div_req_i,
    output logic                        div_rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [1:0]                   div_opc_i,
    input logic [data_width_p-1:0]      div_src0_i,
    input logic [data_width_p-1:0]      div_src1_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                        div_res_vld_o,
    output logic [data_width_p-1:0]     div_res_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [ITAG_WIDTH_P-1:0]      div_itag_i,
    output logic [ITAG_WIDTH_P-1:0]     div_itag_o
    ////////////////////////////////////////////////////////////////////////////////11
);

    assign div_res_vld_o = 1'b0;

endmodule