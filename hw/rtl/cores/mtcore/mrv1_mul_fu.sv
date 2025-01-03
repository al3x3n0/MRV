module mrv1_mul_fu
#(
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = 3,
    parameter NUM_THREADS_P = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                         clk_i,
    input logic                         rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [DATA_WIDTH_P-1:0]      exec_src0_data_i,
    input logic [DATA_WIDTH_P-1:0]      exec_src1_data_i,
    input logic [DATA_WIDTH_P-1:0]      exec_src2_data_i,
    input logic [ITAG_WIDTH_P-1:0]      exec_itag_i,
    input logic [TID_WIDTH_LP-1:0]      exec_tid_i,
    ////////////////////////////////////////////////////////////////////////////////
    input mrv_mul_fu_op_e               mul_fu_opc_i,
    input logic                         mul_fu_req_i,
    output logic                        mul_fu_rdy_o,
    output logic [DATA_WIDTH_P-1:0]     mul_fu_res_o,
    output logic                        mul_fu_done_o,
    output logic [ITAG_WIDTH_P-1:0]     mul_fu_itag_o,
    output logic [TID_WIDTH_LP-1:0]     mul_fu_tid_o
);
    /* Stub */
    assign mul_fu_rdy_o = 1'b0;
    assign mul_fu_done_o = 1'b0;

endmodule