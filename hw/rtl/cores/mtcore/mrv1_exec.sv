module mrv1_exec
#(
    ////////////////////////////////////////////////////////////////////////////////
    parameter PC_WIDTH_P = 32,
    parameter NUM_THREADS_P = 8,
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = 3,
    parameter NUM_FU_P = "inv",
    parameter FU_OPC_WIDTH_P = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                         clk_i,
    input logic                                         rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [PC_WIDTH_P-1:0]                        exec_pc_i,
    input logic [DATA_WIDTH_P-1:0]                      exec_src0_data_i,
    input logic [DATA_WIDTH_P-1:0]                      exec_src1_data_i,
    input logic [DATA_WIDTH_P-1:0]                      exec_src2_data_i,
    input logic [ITAG_WIDTH_P-1:0]                      exec_itag_i,
    input logic [TID_WIDTH_LP-1:0]                      exec_tid_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_FU_P-1:0]                         exec_fu_rdy_o,
    input logic [NUM_FU_P-1:0]                          issue_fu_req_i,
    input logic [FU_OPC_WIDTH_P-1:0]                    issue_fu_opc_i,
    input mrv_vec_mode_e                                issue_fu_vec_mode_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_FU_P-1:0]                         exec_fu_done_o,
    output logic [NUM_FU_P-1:0][DATA_WIDTH_P-1:0]       exec_fu_res_data_o,
    output logic [NUM_FU_P-1:0][ITAG_WIDTH_P-1:0]       exec_fu_itag_o,
    output logic [NUM_FU_P-1:0][TID_WIDTH_LP-1:0]       exec_fu_tid_o,
    ////////////////////////////////////////////////////////////////////////////////
    // Branches
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                         b_is_branch_i,
    input logic                                         b_is_jump_i,
    output logic                                        b_pc_vld_o,
    output logic [PC_WIDTH_P-1:0]                       b_pc_o,
    output logic [TID_WIDTH_LP-1:0]                     b_tid_o,
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
    output logic [TID_WIDTH_LP-1:0]                     th_ctl_tid_o,
    output logic                                        th_ctl_tspawn_vld_o,
    output logic [PC_WIDTH_P-1:0]                       th_ctl_tspawn_pc_o
);
    ////////////////////////////////////////////////////////////////////////////////
    // ALU
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_int_fu #(
        .PC_WIDTH_P         (PC_WIDTH_P),
        .DATA_WIDTH_P       (DATA_WIDTH_P),
        .ITAG_WIDTH_P       (ITAG_WIDTH_P),
        .NUM_THREADS_P      (NUM_THREADS_P)
    ) int_fu_i (
        ////////////////////////////////////////////////////////////////////////////////
        // ISSUE -> EXEC (ALU interface)
        ////////////////////////////////////////////////////////////////////////////////
        .int_fu_rdy_o           (exec_fu_rdy_o[MRV_FU_TYPE_INT]),
        .int_fu_req_i           (issue_fu_req_i[MRV_FU_TYPE_INT]),
        .int_fu_opc_i           (issue_fu_opc_i),
        .int_fu_vec_mode_i      (issue_fu_vec_mode_i),
        .int_fu_bmask0_i        ('0/*FIXME*/),
        .int_fu_bmask1_i        ('0/*FIXME*/),
        .int_fu_imm_vec_ext_i   ('0/*FIXME*/),
        .exec_src0_data_i       (exec_src0_data_i),
        .exec_src1_data_i       (exec_src1_data_i),
        .exec_src2_data_i       (exec_src2_data_i),
        .exec_pc_i              (exec_pc_i),
        .exec_itag_i            (exec_itag_i),
        .exec_tid_i             (exec_tid_i),
        .int_fu_done_o          (exec_fu_done_o[MRV_FU_TYPE_INT]),
        .int_fu_res_o           (exec_fu_res_data_o[MRV_FU_TYPE_INT]),
        .int_fu_itag_o          (exec_fu_itag_o[MRV_FU_TYPE_INT]),
        .int_fu_tid_o           (exec_fu_tid_o[MRV_FU_TYPE_INT]),
        ////////////////////////////////////////////////////////////////////////////////
        // Branches
        ////////////////////////////////////////////////////////////////////////////////
        .b_is_branch_i          (b_is_branch_i),
        .b_is_jump_i            (b_is_jump_i),
        .b_pc_vld_o             (b_pc_vld_o),
        .b_pc_o                 (b_pc_o),
        .b_tid_o                (b_tid_o)
    );
    ////////////////////////////////////////////////////////////////////////////////
    
    ////////////////////////////////////////////////////////////////////////////////
    // MUL 
    ////////////////////////////////////////////////////////////////////////////////xrv1_alu #(
    mrv1_mul_fu #(
        .DATA_WIDTH_P       (DATA_WIDTH_P),
        .ITAG_WIDTH_P       (ITAG_WIDTH_P),
        .NUM_THREADS_P      (NUM_THREADS_P)
    ) mul_fu_i (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .exec_src0_data_i   (exec_src0_data_i),
        .exec_src1_data_i   (exec_src1_data_i),
        .exec_src2_data_i   (exec_src2_data_i),
        .exec_itag_i        (exec_itag_i),
        .exec_tid_i         (exec_tid_i),
        ////////////////////////////////////////////////////////////////////////////////
        .mul_fu_opc_i       (issue_fu_opc_i),
        .mul_fu_req_i       (issue_fu_req_i[MRV_FU_TYPE_MUL]),
        .mul_fu_rdy_o       (exec_fu_rdy_o[MRV_FU_TYPE_MUL]),
        .mul_fu_res_o       (exec_fu_res_data_o[MRV_FU_TYPE_MUL]),
        .mul_fu_done_o      (exec_fu_done_o[MRV_FU_TYPE_MUL]),
        .mul_fu_itag_o      (exec_fu_itag_o[MRV_FU_TYPE_MUL]),
        .mul_fu_tid_o       (exec_fu_tid_o[MRV_FU_TYPE_MUL])
    );
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // LSU IFace 
    ////////////////////////////////////////////////////////////////////////////////
    logic                   lsu_w_en_w;
    logic [1:0]             lsu_size_w;
    logic                   lsu_signed_w;
    assign {
        lsu_signed_w,
        lsu_size_w,
        lsu_w_en_w
    } = issue_fu_opc_i[3:0];

    mrv1_lsu #(
        .DATA_WIDTH_P                   (DATA_WIDTH_P),
        .ITAG_WIDTH_P                   (ITAG_WIDTH_P),
        .NUM_THREADS_P                  (NUM_THREADS_P)
    ) lsu_i (
        .clk_i                          (clk_i),
        .rst_i                          (rst_i),
        .exec_itag_i                    (exec_itag_i),
        .exec_tid_i                     (exec_tid_i),
        .lsu_rdy_o                      (exec_fu_rdy_o[MRV_FU_TYPE_MEM]),
        .lsu_req_i                      (issue_fu_req_i[MRV_FU_TYPE_MEM]),
        .lsu_req_w_en_i                 (lsu_w_en_w),
        .lsu_req_addr_base_i            (exec_src0_data_i),
        .lsu_req_addr_offset_i          (exec_src1_data_i),
        .lsu_req_size_i                 (lsu_size_w),
        .lsu_req_signed_i               (lsu_signed_w),
        .lsu_req_w_data_i               (exec_src2_data_i),
        ////////////////////////////////////////////////////////////////////////////////
        // LSU -> DMEM interface
        ////////////////////////////////////////////////////////////////////////////////
        .dmem_req_vld_o                 (dmem_req_vld_o),
        .dmem_req_rdy_i                 (dmem_req_rdy_i),
        .dmem_resp_err_i                (dmem_resp_err_i),
        .dmem_req_addr_o                (dmem_req_addr_o),
        .dmem_req_w_en_o                (dmem_req_w_en_o),
        .dmem_req_w_be_o                (dmem_req_w_be_o),
        .dmem_req_w_data_o              (dmem_req_w_data_o),
        .dmem_resp_vld_i                (dmem_resp_vld_i),
        .dmem_resp_r_data_i             (dmem_resp_r_data_i),
        ////////////////////////////////////////////////////////////////////////////////
        // Write back interface
        ////////////////////////////////////////////////////////////////////////////////
        .lsu_done_o                     (exec_fu_done_o[MRV_FU_TYPE_MEM]),
        .lsu_wb_data_o                  (exec_fu_res_data_o[MRV_FU_TYPE_MEM]),
        .lsu_itag_o                     (exec_fu_itag_o[MRV_FU_TYPE_MEM]),
        .lsu_tid_o                      (exec_fu_tid_o[MRV_FU_TYPE_MEM])
    );
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // System 
    ////////////////////////////////////////////////////////////////////////////////
    mrv1_sys_fu #(
        .DATA_WIDTH_P                   (DATA_WIDTH_P),
        .ITAG_WIDTH_P                   (ITAG_WIDTH_P),
        .NUM_THREADS_P                  (NUM_THREADS_P)
    ) sys_i (
        .clk_i                          (clk_i),
        .rst_i                          (rst_i),
        .exec_src0_data_i               (exec_src0_data_i),
        .exec_src1_data_i               (exec_src1_data_i),
        .exec_src2_data_i               ('b0),
        .exec_itag_i                    (exec_itag_i),
        .exec_tid_i                     (exec_tid_i),
        ////////////////////////////////////////////////////////////////////////////////
        .sys_fu_opc_i                   (issue_fu_opc_i),
        .sys_fu_req_i                   (issue_fu_req_i[MRV_FU_TYPE_SYS]),
        .sys_fu_rdy_o                   (exec_fu_rdy_o[MRV_FU_TYPE_SYS]),
        .sys_fu_res_o                   (exec_fu_res_data_o[MRV_FU_TYPE_SYS]),
        .sys_fu_done_o                  (exec_fu_done_o[MRV_FU_TYPE_SYS]),
        .sys_fu_itag_o                  (exec_fu_itag_o[MRV_FU_TYPE_SYS]),
        .sys_fu_tid_o                   (exec_fu_tid_o[MRV_FU_TYPE_SYS]),
        ////////////////////////////////////////////////////////////////////////////////
        .th_ctl_vld_o                   (th_ctl_vld_o),
        .th_ctl_tid_o                   (th_ctl_tid_o),
        .th_ctl_tspawn_vld_o            (th_ctl_tspawn_vld_o),
        .th_ctl_tspawn_pc_o             (th_ctl_tspawn_pc_o)
    );
    ////////////////////////////////////////////////////////////////////////////////

endmodule