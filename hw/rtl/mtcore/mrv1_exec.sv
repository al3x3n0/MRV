module mrv1_exec
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_THREADS_P = 8,
    parameter tid_width_lp = $clog2(NUM_THREADS_P),
    ////////////////////////////////////////////////////////////////////////////////
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = 3,
    ////////////////////////////////////////////////////////////////////////////////
    parameter num_fu_lp = 6
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic [DATA_WIDTH_P-1:0]                      exec_src0_data_i,
    input logic [DATA_WIDTH_P-1:0]                      exec_src1_data_i,
    input logic [ITAG_WIDTH_P-1:0]                      exec_itag_i,
    input logic [tid_width_lp-1:0]                      exec_tid_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [num_fu_lp-1:0]                         exec_fu_req_i,
    output logic [num_fu_lp-1:0]                        exec_fu_rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [num_fu_lp-1:0]                        exec_fu_done_o,
    output logic [num_fu_lp-1:0][DATA_WIDTH_P-1:0]      exec_fu_res_data_o,
    output logic [num_fu_lp-1:0][ITAG_WIDTH_P-1:0]      exec_fu_itag_o,
    output logic [num_fu_lp-1:0][tid_width_lp-1:0]      exec_fu_tid_o,
    ////////////////////////////////////////////////////////////////////////////////
    // ALU
    ////////////////////////////////////////////////////////////////////////////////
    input logic [XRV_int_fu_OP_WIDTH-1:0]                  int_fu_opc_i,
    output logic                                        int_fu_cmp_res_o,
    ////////////////////////////////////////////////////////////////////////////////
    // Branches
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                         b_is_branch_i,
    input logic                                         b_is_jump_i,
    output logic                                        b_pc_vld_o,
    output logic [31:0]                                 b_pc_o,
    output logic [tid_width_lp-1:0]                     b_tid_o,
    ////////////////////////////////////////////////////////////////////////////////
    // LSU 
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                         lsu_w_en_i,
    input logic [1:0]                                   lsu_size_i,
    input logic                                         lsu_signed_i,
    ////////////////////////////////////////////////////////////////////////////////
    // LSU <-> Data memory interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        dmem_req_vld_o,
    input  logic                                        dmem_req_rdy_i,
    input  logic                                        dmem_resp_err_i,
    output logic [DATA_WIDTH_P-1:0]                     dmem_req_addr_o,
    output logic                                        dmem_req_w_en_o,
    output logic [3:0]                                  dmem_req_w_be_o,
    output logic [DATA_WIDTH_P-1:0]                     dmem_req_w_data_o,
    input  logic                                        dmem_resp_vld_i,
    input  logic [DATA_WIDTH_P-1:0]                     dmem_resp_r_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    // EXE -> Sched
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                        th_ctl_vld_o,
    output logic [tid_width_lp-1:0]                     th_ctl_tid_o,
    output logic                                        th_ctl_tspawn_vld_o,
    output logic [31:0]                                 th_ctl_tspawn_pc_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    // ALU
    ////////////////////////////////////////////////////////////////////////////////
    logic                                               int_fu_done_lo;
    logic [DATA_WIDTH_P-1:0]                            int_fu_res_lo;
    logic [ITAG_WIDTH_P-1:0]                            int_fu_itag_lo;
    ////////////////////////////////////////////////////////////////////////////////xrv1_alu #(
    mrv1_int_fu #(
        .DATA_WIDTH_P (DATA_WIDTH_P),
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) int_fu_i (
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> EXEC (ALU interface)
        ////////////////////////////////////////////////////////////////////////////////
        .int_fu_rdy_o      (exec_fu_req_i[0]),
        .int_fu_req_i      (exec_fu_rdy_o[0]),
        .int_fu_opc_i      (int_fu_opc_i),
        .int_fu_src0_i     (exec_src0_data_i),
        .int_fu_src1_i     (exec_src1_data_i),
        .int_fu_done_o     (exec_fu_done_o[0]),
        .int_fu_res_o      (exec_fu_res_data_o[0]),
        .int_fu_cmp_res_o  (int_fu_cmp_res_o),
        .int_fu_itag_i     (exec_itag_i),
        .int_fu_itag_o     (exec_fu_itag_o[0]),
        ////////////////////////////////////////////////////////////////////////////////
        // Branches
        ////////////////////////////////////////////////////////////////////////////////
        .b_is_branch_i      (b_is_branch_i),
        .b_is_jump_i        (b_is_jump_i)
        .b_pc_vld_o         (b_pc_vld_o),
        .b_pc_o             (b_pc_o),
        .b_tid_o            (b_tid_o),
        ////////////////////////////////////////////////////////////////////////////////
    );
    assign exec_fu_tid_o[0] = exec_tid_i;
    ////////////////////////////////////////////////////////////////////////////////
);
endmodule