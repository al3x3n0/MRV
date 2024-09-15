module mrv1_exec
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter CORE_ID = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_TW_P = 4,
    parameter twid_width_lp = $clog2(num_warps_p),
    ////////////////////////////////////////////////////////////////////////////////
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = 3
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic [DATA_WIDTH_P-1:0]                      exec_src0_data_i,
    input logic [DATA_WIDTH_P-1:0]                      exec_src1_data_i,
    input logic [ITAG_WIDTH_P-1:0]                      exec_itag_i,
    input logic [twid_width_lp-1:0]                     exec_twid_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [num_fu_lp-1:0]                        exec_fu_done_o,
    output logic [num_fu_lp-1:0][DATA_WIDTH_P-1:0]      exec_fu_res_data_o,
    output logic [num_fu_lp-1:0][ITAG_WIDTH_P-1:0]      exec_fu_itag_o,
    output logic [num_fu_lp-1:0][twid_width_lp-1:0]     exec_fu_twid_o,
    ////////////////////////////////////////////////////////////////////////////////
    // ALU
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 alu_req_i,
    output logic                                alu_rdy_o,
    input logic [XRV_ALU_OP_WIDTH-1:0]          alu_opc_i,
    output logic                                alu_cmp_res_o,
    ////////////////////////////////////////////////////////////////////////////////
    // MUL
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    // ALU
    ////////////////////////////////////////////////////////////////////////////////
    logic                           alu_done_lo;
    logic [DATA_WIDTH_P-1:0]        alu_res_lo;
    logic [ITAG_WIDTH_P-1:0]        alu_itag_lo;
    ////////////////////////////////////////////////////////////////////////////////xrv1_alu #(
    xrv1_alu #(
        .DATA_WIDTH_P (DATA_WIDTH_P),
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) alu_i (
        // ISSUE -> EXEC (ALU interface)
        ////////////////////////////////////////////////////////////////////////////////
        .alu_rdy_o      (alu_rdy_o),
        .alu_req_i      (alu_req_i),
        .alu_opc_i      (alu_opc_i),
        .alu_src0_i     (exec_src0_data_i),
        .alu_src1_i     (exec_src1_data_i),
        .alu_done_o     (alu_done_lo),
        .alu_res_o      (alu_res_lo),
        .alu_cmp_res_o  (alu_cmp_res_o),
        .alu_itag_i     (exec_itag_i),
        .alu_itag_o     (alu_itag_lo)
    );
    ////////////////////////////////////////////////////////////////////////////////
);
endmodule