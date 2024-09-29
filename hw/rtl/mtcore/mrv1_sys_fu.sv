module mrv1_sys_fu
#(
    parameter DATA_WIDTH_P = 32,
    parameter ITAG_WIDTH_P = 3,
    parameter NUM_THREADS_P = "inv",
    parameter PC_WIDTH_P = 32,
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
    input mrv_sys_fu_op_e               sys_fu_opc_i,
    input logic                         sys_fu_req_i,
    output logic                        sys_fu_rdy_o,
    output logic [DATA_WIDTH_P-1:0]     sys_fu_res_o,
    output logic                        sys_fu_done_o,
    output logic [ITAG_WIDTH_P-1:0]     sys_fu_itag_o,
    output logic [TID_WIDTH_LP-1:0]     sys_fu_tid_o,
    ////////////////////////////////////////////////////////////////////////////////
    // Thread Control
    ////////////////////////////////////////////////////////////////////////////////
    output logic                        th_ctl_vld_o,
    output logic [TID_WIDTH_LP-1:0]     th_ctl_tid_o,
    output logic                        th_ctl_tspawn_vld_o,
    output logic [PC_WIDTH_P-1:0]       th_ctl_tspawn_pc_o
);
    ////////////////////////////////////////////////////////////////////////////////
    assign sys_fu_rdy_o = 1'b1;
    assign sys_fu_done_o = sys_fu_req_i;
    assign sys_fu_itag_o = exec_itag_i;

    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0] csr_w_data_r;
    logic [DATA_WIDTH_P-1:0] csr_r_data_lo;
    always_comb begin
        case (sys_fu_opc_i)
            MRV_SYS_FU_CSR_WRITE: csr_w_data_r = exec_src0_data_i;
            MRV_SYS_FU_CSR_SET: csr_w_data_r = exec_src0_data_i | csr_r_data_lo;
            MRV_SYS_FU_CSR_CLR: csr_w_data_r = ~exec_src0_data_i & csr_r_data_lo;
            MRV_SYS_FU_CSR_READ: csr_w_data_r = exec_src0_data_i;
            default:;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    logic csr_w_en_li = sys_fu_opc_i != MRV_SYS_FU_CSR_READ;

    ////////////////////////////////////////////////////////////////////////////////
    // CSR File
    ////////////////////////////////////////////////////////////////////////////////
    logic [11:0] csr_addr_w     = exec_src1_data_i[11:0];
    mrv1_csrf #(
        .DATA_WIDTH_P           (DATA_WIDTH_P),
        .NUM_THREADS_P          (NUM_THREADS_P),
    ) csrf_i (
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        .csr_addr_i             (csr_addr_w),
        .csr_r_data_o           (csr_r_data_lo),
        .csr_w_en_i             (csr_w_en_li),
        .csr_w_data_i           (csr_w_data_r)
    );
    assign sys_fu_res_o = csr_r_data_lo;
    
    ////////////////////////////////////////////////////////////////////////////////
    // Thread Control
    ////////////////////////////////////////////////////////////////////////////////

endmodule