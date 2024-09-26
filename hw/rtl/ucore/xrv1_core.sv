module xrv1_core
#(
    parameter ITAG_WIDTH_P = 2,
    parameter DATA_WIDTH_P = 32,
    parameter CORE_RESET_ADDR = 'h2000,
    parameter rf_addr_width_p = 5,
    ////////////////////////////////////////////////////////////////////////////////
    parameter iqueue_size_lp = (1 << ITAG_WIDTH_P),
    ////////////////////////////////////////////////////////////////////////////////
    parameter num_rs_lp = 2,
    parameter num_fu_lp = 6
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                     clk_i,
    input logic                     rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Instruction memory interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                    imem_req_vld_o,
    input logic                     imem_req_rdy_i,
    output logic [31:0]             imem_req_addr_o,
    input logic                     imem_resp_vld_i,
    input logic [31:0]              imem_resp_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Data memory interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                    dmem_req_vld_o,
    input  logic                    dmem_req_rdy_i,
    input  logic                    dmem_resp_err_i,
    output logic [31:0]             dmem_req_addr_o,
    output logic                    dmem_req_w_en_o,
    output logic [3:0]              dmem_req_w_be_o,
    output logic [31:0]             dmem_req_w_data_o,
    input  logic                    dmem_resp_vld_i,
    input  logic [31:0]             dmem_resp_r_data_i
    ////////////////////////////////////////////////////////////////////////////////
);

    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0]                    ifetch_insn_data_lo;
    logic                           ifetch_insn_vld_lo;
    logic [31:0]                    ifetch_insn_pc_lo;
    logic                           ifetch_insn_compressed_lo;
    logic                           ifetch_insn_illegal_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0]                    ifetch_insn_data_q;
    logic                           ifetch_insn_vld_q;
    logic [31:0]                    ifetch_insn_pc_q;
    logic                           ifetch_insn_compressed_q;
    logic                           ifetch_insn_illegal_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           idecode_rdy_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0]                    idecode_insn_li;
    logic [31:0]                    idecode_insn_pc_li;
    logic                           idecode_insn_vld_li;
    logic                           idecode_insn_compressed_li;
    logic                           idecode_insn_illegal_li;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           idecode_j_pc_vld_lo;
    logic [31:0]                    idecode_j_pc_lo;
    logic [31:0]                    idecode_next_pc_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_b_pc_vld_lo;
    logic [31:0]                    exec_b_pc_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [rf_addr_width_p-1:0]     idecode_rs0_addr_lo;
    logic [rf_addr_width_p-1:0]     idecode_rs1_addr_lo;
    logic [rf_addr_width_p-1:0]     idecode_rd_addr_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           idecode_rs0_vld_lo;
    logic                           idecode_rs1_vld_lo;
    logic                           idecode_rd_vld_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0]        rf_rs0_data_lo;
    logic [DATA_WIDTH_P-1:0]        rf_rs1_data_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0]        idecode_src0_data_lo;
    logic [DATA_WIDTH_P-1:0]        idecode_src1_data_lo;
    logic [DATA_WIDTH_P-1:0]        idecode_src2_data_lo;
    logic [ITAG_WIDTH_P-1:0]        idecode_itag_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           idecode_issue_vld_lo;
    logic                           iq_issue_rdy_lo;
    logic                           iq_retire_rdy_lo;
    logic [ITAG_WIDTH_P-1:0]        iq_issue_itag_lo;
    logic [ITAG_WIDTH_P-1:0]        iq_retire_itag_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           iq_retire_rd_addr_vld_lo;
    logic [rf_addr_width_p-1:0]     iq_retire_rd_addr_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0]        exec_src0_data_q;
    logic [DATA_WIDTH_P-1:0]        exec_src1_data_q;
    logic [DATA_WIDTH_P-1:0]        exec_src2_data_q;
    logic [ITAG_WIDTH_P-1:0]        exec_itag_q;
    logic [31:0]                    exec_next_pc_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0]        exec_src0_data_li;
    logic [DATA_WIDTH_P-1:0]        exec_src1_data_li;
    logic [DATA_WIDTH_P-1:0]        exec_src2_data_li;
    logic [ITAG_WIDTH_P-1:0]        exec_itag_li;
    logic [31:0]                    exec_next_pc_li;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           alu_rdy_lo;
    logic                           idecode_alu_req_vld_lo;
    logic [XRV_ALU_OP_WIDTH-1:0]    idecode_alu_opc_lo;
    /////////////////////////////////////////////////////////////////////////////
    logic                           exec_alu_req_vld_q;
    logic [XRV_ALU_OP_WIDTH-1:0]    exec_alu_opc_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           alu_req_vld_li;
    logic [XRV_ALU_OP_WIDTH-1:0]    alu_opc_li;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           alu_done_lo;
    logic [DATA_WIDTH_P-1:0]        alu_res_lo;
    logic                           alu_cmp_res_lo;
    logic [ITAG_WIDTH_P-1:0]        alu_itag_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           b_rdy_lo;
    logic                           b_done_lo;
    logic [ITAG_WIDTH_P-1:0]        b_itag_lo;
    logic [31:0]                    b_wb_data_lo;
    logic                           idecode_b_req_vld_lo;
    logic                           idecode_b_is_branch_lo;
    logic                           idecode_b_is_jump_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_b_req_vld_q;
    logic                           exec_b_is_branch_q;
    logic                           exec_b_is_jump_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_b_req_vld_li;
    logic                           exec_b_is_branch_li;
    logic                           exec_b_is_jump_li;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           lsu_rdy_lo;
    logic                           idecode_lsu_req_vld_lo;
    logic                           idecode_lsu_req_w_en_lo;
    logic [1:0]                     idecode_lsu_req_size_lo;
    logic                           idecode_lsu_req_signed_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_lsu_req_vld_q;
    logic                           exec_lsu_req_w_en_q;
    logic [1:0]                     exec_lsu_req_size_q;
    logic                           exec_lsu_req_signed_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_lsu_req_vld_li;
    logic                           exec_lsu_req_w_en_li;
    logic [1:0]                     exec_lsu_req_size_li;
    logic                           exec_lsu_req_signed_li;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           lsu_done_lo;
    logic [DATA_WIDTH_P-1:0]        lsu_wb_data_lo;
    logic [ITAG_WIDTH_P-1:0]        lsu_itag_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           mul_rdy_lo;
    logic                           idecode_mul_req_vld_lo;
    logic [1:0]                     idecode_mul_opc_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_mul_req_vld_q;
    logic [1:0]                     exec_mul_opc_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           mul_req_vld_li;
    logic [1:0]                     mul_opc_li;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           mul_res_vld_lo;
    logic [DATA_WIDTH_P-1:0]        mul_res_lo;
    logic [ITAG_WIDTH_P-1:0]        mul_itag_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           div_rdy_lo;
    logic                           idecode_div_req_vld_lo;
    logic [1:0]                     idecode_div_opc_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_div_req_vld_q;
    logic [1:0]                     exec_div_opc_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           div_req_vld_li;
    logic [1:0]                     div_opc_li;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           div_res_vld_lo;
    logic [DATA_WIDTH_P-1:0]        div_res_lo;
    logic [ITAG_WIDTH_P-1:0]        div_itag_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           csr_rdy_lo;
    logic                           idecode_csr_req_vld_lo;
    logic [1:0]                     idecode_csr_opc_lo;
    logic [11:0]                    idecode_csr_addr_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           exec_csr_req_vld_q;
    logic [1:0]                     exec_csr_opc_q;
    logic [11:0]                    exec_csr_addr_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           csr_req_vld_li;
    logic [1:0]                     csr_opc_li;
    logic [11:0]                    csr_addr_li;
    ////////////////////////////////////////////////////////////////////////////////
    logic                           csr_done_lo;
    logic [31:0]                    csr_data_lo;
    logic [ITAG_WIDTH_P-1:0]        csr_itag_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [rf_addr_width_p-1:0]     wb_rd_addr_lo;
    logic                           wb_data_vld_lo;
    logic [DATA_WIDTH_P-1:0]        wb_data_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [ITAG_WIDTH_P-1:0]        ret_retire_cnt_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [num_rs_lp-1:0]           ret_rs_byp_en_lo;
    logic [num_rs_lp-1:0][31:0]     ret_rs_byp_data_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [num_rs_lp-1:0]           ret_rs_conflict_lo;

    ////////////////////////////////////////////////////////////////////////////////
    logic rst_flag_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i)
            rst_flag_q <= 1'b1;
        else if (rst_flag_q)
            rst_flag_q <= 1'b0;
    end
    ////////////////////////////////////////////////////////////////////////////////
    wire rst_down_w = rst_flag_q;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction fetch unit
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_ifetch #(.ifq_default_reset_addr(CORE_RESET_ADDR)) ifetch (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        .rst_down_i                 (rst_down_w),
        ////////////////////////////////////////////////////////////////////////////////
        // FETCH -> DECODE interface
        ////////////////////////////////////////////////////////////////////////////////
        .decode_rdy_i               (idecode_rdy_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .exec_b_pc_vld_i            (exec_b_pc_vld_lo),
        .exec_b_pc_i                (exec_b_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .dec_j_pc_vld_i             (idecode_j_pc_vld_lo),
        .dec_j_pc_i                 (idecode_j_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .ifetch_insn_vld_o          (ifetch_insn_vld_lo),
        .ifetch_insn_data_o         (ifetch_insn_data_lo),
        .ifetch_insn_pc_o           (ifetch_insn_pc_lo),
        .ifetch_insn_compressed_o   (ifetch_insn_compressed_lo),
        .ifetch_insn_illegal_o      (ifetch_insn_illegal_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // FETCH -> IMEM interface
        ////////////////////////////////////////////////////////////////////////////////
        .imem_req_vld_o             (imem_req_vld_o),
        .imem_req_rdy_i             (imem_req_rdy_i),
        .imem_req_addr_o            (imem_req_addr_o),
        .imem_resp_vld_i            (imem_resp_vld_i),
        .imem_resp_data_i           (imem_resp_data_i)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // IF/DEC Stage FF
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_down_w | idecode_j_pc_vld_lo | exec_b_pc_vld_lo) begin
            ifetch_insn_vld_q       <= 'b0;
        end
        else if (idecode_rdy_lo) begin
            ifetch_insn_data_q       <= ifetch_insn_data_lo;
            ifetch_insn_pc_q         <= ifetch_insn_pc_lo;
            ifetch_insn_vld_q        <= ifetch_insn_vld_lo;
            ifetch_insn_compressed_q <= ifetch_insn_compressed_lo;
            ifetch_insn_illegal_q    <= ifetch_insn_illegal_lo;
        end
    end

    ////////////////////////////////////////////////////////////////////////////////
    assign idecode_insn_li            = ifetch_insn_data_q;
    assign idecode_insn_pc_li         = ifetch_insn_pc_q;
    assign idecode_insn_vld_li        = ifetch_insn_vld_q;
    assign idecode_insn_compressed_li = ifetch_insn_compressed_q;
    assign idecode_insn_illegal_li    = ifetch_insn_illegal_q;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Instruction decode unit
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_idecode #(
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) idecode (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        // FETCH -> DECODE interface
        ////////////////////////////////////////////////////////////////////////////////
        .decode_rdy_o               (idecode_rdy_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .insn_i                     (idecode_insn_li),
        .insn_pc_i                  (idecode_insn_pc_li),
        .insn_vld_i                 (idecode_insn_vld_li),
        .insn_is_rv16_i             (idecode_insn_compressed_li),
        .insn_illegal_i             (idecode_insn_illegal_li),
        ////////////////////////////////////////////////////////////////////////////////
        .insn_illegal_o             (/*FIXME*/),
        ////////////////////////////////////////////////////////////////////////////////
        .j_pc_vld_o                 (idecode_j_pc_vld_lo),
        .j_pc_o                     (idecode_j_pc_lo),
        .insn_next_pc_o             (idecode_next_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE -> Issue queue interface
        ////////////////////////////////////////////////////////////////////////////////
        .issue_rdy_i                (iq_issue_rdy_lo),
        .issue_itag_i               (iq_issue_itag_lo),
        .issue_vld_o                (idecode_issue_vld_lo),
        .exec_b_flush_i             (exec_b_pc_vld_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .retire_vld_i               (wb_data_vld_lo),
        .retire_rd_addr_vld_i       (iq_retire_rd_addr_vld_lo),
        .retire_rd_addr_i           (iq_retire_rd_addr_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE -> RF interface
        ////////////////////////////////////////////////////////////////////////////////
        // Read port 0
        ////////////////////////////////////////////////////////////////////////////////
        .rs0_addr_o                 (idecode_rs0_addr_lo),
        .rs0_data_i                 (rf_rs0_data_lo),
        .rs0_vld_o                  (idecode_rs0_vld_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // Read port 1
        ////////////////////////////////////////////////////////////////////////////////
        .rs1_addr_o                 (idecode_rs1_addr_lo),
        .rs1_data_i                 (rf_rs1_data_lo),
        .rs1_vld_o                  (idecode_rs1_vld_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // Write port 0
        ////////////////////////////////////////////////////////////////////////////////
        .rd_addr_o                  (idecode_rd_addr_lo),
        .rd_vld_o                   (idecode_rd_vld_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .rs_conflict_i              (ret_rs_conflict_lo),
        .rs0_byp_en_i               (ret_rs_byp_en_lo[0]),
        .rs1_byp_en_i               (ret_rs_byp_en_lo[1]),
        .rs0_byp_data_i             (ret_rs_byp_data_lo[0]),
        .rs1_byp_data_i             (ret_rs_byp_data_lo[1]),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE -> EXE interface
        ////////////////////////////////////////////////////////////////////////////////
        .exec_src0_o                (idecode_src0_data_lo),
        .exec_src1_o                (idecode_src1_data_lo),
        .exec_src2_o                (idecode_src2_data_lo),
        .exec_itag_o                (idecode_itag_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE -> EXE(ALU) interface
        ////////////////////////////////////////////////////////////////////////////////
        .alu_rdy_i                  (alu_rdy_lo),
        .alu_req_vld_o              (idecode_alu_req_vld_lo),
        .alu_opc_o                  (idecode_alu_opc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE <-> BRANCH interface
        ////////////////////////////////////////////////////////////////////////////////
        .b_rdy_i                    (b_rdy_lo),
        .b_req_vld_o                (idecode_b_req_vld_lo),
        .b_is_branch_o              (idecode_b_is_branch_lo),
        .b_is_jump_o                (idecode_b_is_jump_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE <-> EXE(CSR) interface
        ////////////////////////////////////////////////////////////////////////////////
        .csr_rdy_i                  (csr_rdy_lo),
        .csr_req_vld_o              (idecode_csr_req_vld_lo),
        .csr_opc_o                  (idecode_csr_opc_lo),
        .csr_addr_o                 (idecode_csr_addr_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE <-> EXE(LSU) interface
        ////////////////////////////////////////////////////////////////////////////////
        .lsu_rdy_i                  (lsu_rdy_lo),
        .lsu_req_vld_o              (idecode_lsu_req_vld_lo),
        .lsu_req_w_en_o             (idecode_lsu_req_w_en_lo),
        .lsu_req_size_o             (idecode_lsu_req_size_lo),
        .lsu_req_signed_o           (idecode_lsu_req_signed_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE -> EXE(MUL) interface
        ////////////////////////////////////////////////////////////////////////////////
        .mul_rdy_i                  (mul_rdy_lo),
        .mul_req_vld_o              (idecode_mul_req_vld_lo),
        .mul_opc_o                  (idecode_mul_opc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE -> EXE(DIV/REM) interface
        ////////////////////////////////////////////////////////////////////////////////
        .div_rdy_i                  (div_rdy_lo),
        .div_req_vld_o              (idecode_div_req_vld_lo),
        .div_opc_o                  (idecode_div_opc_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Issued instruction queue
    ////////////////////////////////////////////////////////////////////////////////
    logic [num_rs_lp-1:0][rf_addr_width_p-1:0]      iq_issue_rs_addr_li;
    logic [num_rs_lp-1:0]                           iq_issue_rs_vld_li;
    logic [num_rs_lp-1:0][iqueue_size_lp-1:0]       iq_rs_conflict_lo;
    ////////////////////////////////////////////////////////////////////////////////
    assign iq_issue_rs_addr_li[0] = idecode_rs0_addr_lo;
    assign iq_issue_rs_addr_li[1] = idecode_rs1_addr_lo;
    assign iq_issue_rs_vld_li[0] = idecode_rs0_vld_lo;
    assign iq_issue_rs_vld_li[1] = idecode_rs1_vld_lo;
    ////////////////////////////////////////////////////////////////////////////////
    logic [iqueue_size_lp-1:0]                      iq_vld_lo;
    logic [iqueue_size_lp-1:0]                      iq_rd_vld_lo;
    logic [iqueue_size_lp-1:0][rf_addr_width_p-1:0] iq_rd_addr_lo;
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_iqueue #(
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    )iqueue (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i | rst_down_w),
        ////////////////////////////////////////////////////////////////////////////////
        .issue_rdy_o                (iq_issue_rdy_lo),
        .issue_vld_i                (idecode_issue_vld_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .retire_rdy_o               (iq_retire_rdy_lo),
        .retire_cnt_i               (ret_retire_cnt_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .issue_rs_addr_i            (iq_issue_rs_addr_li),
        .issue_rs_vld_i             (iq_issue_rs_vld_li),
        ////////////////////////////////////////////////////////////////////////////////
        .issue_rd_addr_i            (idecode_rd_addr_lo),
        .issue_rd_vld_i             (idecode_rd_vld_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .issue_itag_o               (iq_issue_itag_lo),
        .retire_itag_o              (iq_retire_itag_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .retire_rd_addr_vld_o       (iq_retire_rd_addr_vld_lo),
        .retire_rd_addr_o           (iq_retire_rd_addr_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .rs_conflict_o              (iq_rs_conflict_lo),
        .iqueue_vld_o               (iq_vld_lo),
        .iqueue_rd_vld_o            (iq_rd_vld_lo),
        .iqueue_rd_addr_o           (iq_rd_addr_lo)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Register File
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_rf #(
        .DATA_WIDTH_P (DATA_WIDTH_P)
    ) rf (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        // Read port 0
        ////////////////////////////////////////////////////////////////////////////////
        .rs0_addr_i                 (idecode_rs0_addr_lo),
        .rs0_data_o                 (rf_rs0_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // Read port 1
        ////////////////////////////////////////////////////////////////////////////////
        .rs1_addr_i                 (idecode_rs1_addr_lo),
        .rs1_data_o                 (rf_rs1_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // Write port 0
        ////////////////////////////////////////////////////////////////////////////////
        .rd_w_en_i                  (wb_data_vld_lo),
        .rd_addr_i                  (wb_rd_addr_lo),
        .rd_data_i                  (wb_data_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    ////////////////////////////////////////////////////////////////////////////////
    // DEC/EXE Stage FF
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_down_w | exec_b_pc_vld_lo | ~idecode_issue_vld_lo) begin
            ////////////////////////////////////////////////////////////////////////////////
            exec_alu_req_vld_q      <= 'b0;
            exec_b_req_vld_q        <= 'b0;
            exec_lsu_req_vld_q      <= 'b0;
            exec_mul_req_vld_q      <= 'b0;
            exec_div_req_vld_q      <= 'b0;
            exec_csr_req_vld_q      <= 'b0;
            ////////////////////////////////////////////////////////////////////////////////
        end
        else if (idecode_issue_vld_lo) begin
            exec_alu_req_vld_q      <= idecode_alu_req_vld_lo;
            exec_b_req_vld_q        <= idecode_b_req_vld_lo;
            exec_lsu_req_vld_q      <= idecode_lsu_req_vld_lo;
            exec_mul_req_vld_q      <= idecode_mul_req_vld_lo;
            exec_div_req_vld_q      <= idecode_div_req_vld_lo;
            exec_itag_q             <= idecode_itag_lo;
            exec_csr_req_vld_q      <= idecode_csr_req_vld_lo;
        end
        ////////////////////////////////////////////////////////////////////////////////
        exec_src0_data_q        <= idecode_src0_data_lo;
        exec_src1_data_q        <= idecode_src1_data_lo;
        exec_src2_data_q        <= idecode_src2_data_lo;
        ////////////////////////////////////////////////////////////////////////////////
        exec_next_pc_q          <= idecode_next_pc_lo;
        ////////////////////////////////////////////////////////////////////////////////
        exec_alu_opc_q          <= idecode_alu_opc_lo;
        ////////////////////////////////////////////////////////////////////////////////
        exec_b_is_branch_q      <= idecode_b_is_branch_lo;
        exec_b_is_jump_q        <= idecode_b_is_jump_lo;
        ////////////////////////////////////////////////////////////////////////////////
        exec_lsu_req_w_en_q     <= idecode_lsu_req_w_en_lo;
        exec_lsu_req_size_q     <= idecode_lsu_req_size_lo;
        exec_lsu_req_signed_q   <= idecode_lsu_req_signed_lo;
        ////////////////////////////////////////////////////////////////////////////////
        exec_mul_opc_q          <= idecode_mul_opc_lo;
        ////////////////////////////////////////////////////////////////////////////////
        exec_div_opc_q          <= idecode_div_opc_lo;
        ////////////////////////////////////////////////////////////////////////////////
        exec_csr_opc_q          <= idecode_csr_opc_lo;
        exec_csr_addr_q         <= idecode_csr_addr_lo;
        ////////////////////////////////////////////////////////////////////////////////
    end
    ////////////////////////////////////////////////////////////////////////////////
    assign exec_src0_data_li        = exec_src0_data_q;
    assign exec_src1_data_li        = exec_src1_data_q;
    assign exec_src2_data_li        = exec_src2_data_q;
    assign exec_itag_li             = exec_itag_q;
    assign exec_next_pc_li          = exec_next_pc_q;
    ////////////////////////////////////////////////////////////////////////////////
    assign alu_req_vld_li           = exec_alu_req_vld_q;
    assign alu_opc_li               = exec_alu_opc_q;
    ////////////////////////////////////////////////////////////////////////////////
    assign exec_b_req_vld_li       = exec_b_req_vld_q;
    assign exec_b_is_branch_li     = exec_b_is_branch_q;
    assign exec_b_is_jump_li       = exec_b_is_jump_q;
    ////////////////////////////////////////////////////////////////////////////////
    assign exec_lsu_req_vld_li      = exec_lsu_req_vld_q;
    assign exec_lsu_req_w_en_li     = exec_lsu_req_w_en_q;
    assign exec_lsu_req_size_li     = exec_lsu_req_size_q;
    assign exec_lsu_req_signed_li   = exec_lsu_req_signed_q;
    ////////////////////////////////////////////////////////////////////////////////
    assign mul_req_vld_li           = exec_mul_req_vld_q;
    assign mul_opc_li               = exec_mul_opc_q;
    ////////////////////////////////////////////////////////////////////////////////
    assign div_req_vld_li           = exec_div_req_vld_q;
    assign div_opc_li               = exec_div_opc_q;
    ////////////////////////////////////////////////////////////////////////////////
    assign csr_req_vld_li           = exec_csr_req_vld_q;
    assign csr_opc_li               = exec_csr_opc_q;
    assign csr_addr_li              = exec_csr_addr_q;

    ////////////////////////////////////////////////////////////////////////////////
    // ALU
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_alu #(
        .DATA_WIDTH_P (DATA_WIDTH_P),
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) alu_i (
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE -> ALU interface
        ////////////////////////////////////////////////////////////////////////////////
        .alu_rdy_o    (alu_rdy_lo),
        .alu_req_i    (alu_req_vld_li),
        .alu_opc_i    (alu_opc_li),
        ////////////////////////////////////////////////////////////////////////////////
        .alu_src0_i   (exec_src0_data_li),
        .alu_src1_i   (exec_src1_data_li),
        ////////////////////////////////////////////////////////////////////////////////
        .alu_done_o   (alu_done_lo),
        .alu_res_o    (alu_res_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .alu_cmp_res_o(alu_cmp_res_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .alu_itag_i   (exec_itag_li),
        .alu_itag_o   (alu_itag_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    xrv1_branch #(
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) bu_i (
        ////////////////////////////////////////////////////////////////////////////////
        .b_rdy_o                        (b_rdy_lo),
        .b_req_i                        (exec_b_req_vld_li),
        .b_done_o                       (b_done_lo),
        .b_is_branch_i                  (exec_b_is_branch_li),
        .b_is_jump_i                    (exec_b_is_jump_li),
        ////////////////////////////////////////////////////////////////////////////////
        .next_pc_i                      (exec_next_pc_li),
        ////////////////////////////////////////////////////////////////////////////////
        .exec_b_pc_vld_o                (exec_b_pc_vld_lo),
        .exec_b_pc_o                    (exec_b_pc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .alu_cmp_res_i                  (alu_cmp_res_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .b_wb_data_o                    (b_wb_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .b_itag_i                       (exec_itag_li),
        .b_itag_o                       (b_itag_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Multiplication unit
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_mul #(
        .DATA_WIDTH_P (DATA_WIDTH_P),
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    )mul_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                          (clk_i),
        .rst_i                          (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        // DECODE -> MUL interface
        ////////////////////////////////////////////////////////////////////////////////
        .mul_rdy_o                      (mul_rdy_lo),
        .mul_req_i                      (idecode_mul_req_vld_lo),
        .mul_opc_i                      (idecode_mul_opc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .mul_src0_i                     (exec_src0_data_li),
        .mul_src1_i                     (exec_src1_data_li),
        ////////////////////////////////////////////////////////////////////////////////
        .mul_res_vld_o                  (mul_res_vld_lo),
        .mul_res_o                      (mul_res_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .mul_itag_i                     (exec_itag_li),
        .mul_itag_o                     (mul_itag_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Division/remainder unit
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_div #(
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    )div_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                          (clk_i),
        .rst_i                          (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .div_rdy_o                      (div_rdy_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .div_req_i                      (idecode_div_req_vld_lo),
        .div_opc_i                      (idecode_div_opc_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .div_src0_i                     (exec_src0_data_li),
        .div_src1_i                     (exec_src1_data_li),
        ////////////////////////////////////////////////////////////////////////////////
        .div_res_vld_o                  (div_res_vld_lo),
        .div_res_o                      (div_res_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .div_itag_i                     (exec_itag_li),
        .div_itag_o                     (div_itag_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    ////////////////////////////////////////////////////////////////////////////////
    // LSU
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_lsu #(
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) lsu_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                          (clk_i),
        .rst_i                          (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .lsu_rdy_o                      (lsu_rdy_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .lsu_req_vld_i                  (exec_lsu_req_vld_li),
        .lsu_req_w_en_i                 (exec_lsu_req_w_en_li),
        .lsu_req_addr_base_i            (exec_src0_data_li),
        .lsu_req_addr_offset_i          (exec_src1_data_li),
        .lsu_req_size_i                 (exec_lsu_req_size_li),
        .lsu_req_signed_i               (exec_lsu_req_signed_li),
        .lsu_req_w_data_i               (exec_src2_data_li),
        ////////////////////////////////////////////////////////////////////////////////
        // LSU -> DMEM interface
        ////////////////////////////////////////////////////////////////////////////////
        .dmem_req_vld_o                 (dmem_req_vld_o),
        .dmem_req_rdy_i                 (dmem_req_rdy_i),
        .dmem_resp_err_i                (/*FIXME*/),
        .dmem_req_addr_o                (dmem_req_addr_o),
        .dmem_req_w_en_o                (dmem_req_w_en_o),
        .dmem_req_w_be_o                (dmem_req_w_be_o),
        .dmem_req_w_data_o              (dmem_req_w_data_o),
        .dmem_resp_vld_i                (dmem_resp_vld_i),
        .dmem_resp_r_data_i             (dmem_resp_r_data_i),
        ////////////////////////////////////////////////////////////////////////////////
        // Write back interface
        ////////////////////////////////////////////////////////////////////////////////
        .lsu_done_o                     (lsu_done_lo),
        .lsu_wb_data_o                  (lsu_wb_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .lsu_itag_i                     (exec_itag_li),
        .lsu_itag_o                     (lsu_itag_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    ////////////////////////////////////////////////////////////////////////////////
    // CSRs
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_csr csr_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                          (clk_i),
        .rst_i                          (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .csr_rdy_o                      (csr_rdy_lo),
        .csr_req_vld_i                  (csr_req_vld_li),
        .csr_opc_i                      (csr_opc_li),
        .csr_src0_i                     (exec_src0_data_li),
        .csr_addr_i                     (csr_addr_li),
        ////////////////////////////////////////////////////////////////////////////////
        .csr_done_o                     (csr_done_lo),
        .csr_data_o                     (csr_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .csr_itag_i                     (exec_itag_li),
        .csr_itag_o                     (csr_itag_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );


    ////////////////////////////////////////////////////////////////////////////////
    // RF Writeback
    ////////////////////////////////////////////////////////////////////////////////
    logic [num_fu_lp-1:0]                   fu_done_li;
    logic [num_fu_lp-1:0][ITAG_WIDTH_P-1:0] fu_wb_itag_li;
    logic [num_fu_lp-1:0][31:0]             fu_wb_data_li;
    ////////////////////////////////////////////////////////////////////////////////
    assign fu_done_li[0] = alu_done_lo;
    assign fu_done_li[1] = b_done_lo;
    assign fu_done_li[2] = lsu_done_lo;
    assign fu_done_li[3] = csr_done_lo;
    assign fu_done_li[4] = 1'b0; // MUL FIXME
    assign fu_done_li[5] = 1'b0; // DIV FIXME
    ////////////////////////////////////////////////////////////////////////////////
    assign fu_wb_itag_li[0] = alu_itag_lo;
    assign fu_wb_itag_li[1] = b_itag_lo;
    assign fu_wb_itag_li[2] = lsu_itag_lo;
    assign fu_wb_itag_li[3] = csr_itag_lo;
    assign fu_wb_itag_li[4] = '0; // MUL FIXME
    assign fu_wb_itag_li[5] = '0; // DIV FIXME
    ////////////////////////////////////////////////////////////////////////////////
    assign fu_wb_data_li[0] = alu_res_lo;
    assign fu_wb_data_li[1] = b_wb_data_lo;
    assign fu_wb_data_li[2] = lsu_wb_data_lo;
    assign fu_wb_data_li[3] = csr_data_lo;
    assign fu_wb_data_li[4] = '0; // MUL FIXME
    assign fu_wb_data_li[5] = '0; // DIV FIXME
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_retire #(
        .DATA_WIDTH_P (DATA_WIDTH_P),
        .ITAG_WIDTH_P (ITAG_WIDTH_P)
    ) wback (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                          (clk_i),
        .rst_i                          (rst_i | rst_down_w),
        ////////////////////////////////////////////////////////////////////////////////
        .fu_done_i                      (fu_done_li),
        .fu_wb_data_i                   (fu_wb_data_li),
        .fu_itag_i                      (fu_wb_itag_li),
        ////////////////////////////////////////////////////////////////////////////////
        // IQ <-> WBACK
        ////////////////////////////////////////////////////////////////////////////////
        .issue_itag_i                   (iq_issue_itag_lo),
        .retire_rdy_i                   (iq_retire_rdy_lo),
        .retire_cnt_o                   (ret_retire_cnt_lo),
        .retire_itag_i                  (iq_retire_itag_lo),
        .retire_rd_addr_i               (iq_retire_rd_addr_lo),
        ////////////////////////////////////////////////////////////////////////////////
        // WBACK <-> RF
        ////////////////////////////////////////////////////////////////////////////////
        .wb_rd_addr_o                   (wb_rd_addr_lo),
        .wb_data_vld_o                  (wb_data_vld_lo),
        .wb_data_o                      (wb_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .rs_conflict_i                  (iq_rs_conflict_lo),
        .rs_conflict_o                  (ret_rs_conflict_lo),
        .rs_byp_en_o                    (ret_rs_byp_en_lo),
        .rs_byp_data_o                  (ret_rs_byp_data_lo),
        ////////////////////////////////////////////////////////////////////////////////
        .iqueue_vld_i                   (iq_vld_lo),
        .iqueue_rd_vld_i                (iq_rd_vld_lo),
        .iqueue_rd_addr_i               (iq_rd_addr_lo)
        ////////////////////////////////////////////////////////////////////////////////
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Verification functions
    ////////////////////////////////////////////////////////////////////////////////

    function [7:0] get_imem_resp_vld;
        /*verilator public*/
        get_imem_resp_vld = 8'(imem_resp_vld_i);
    endfunction

    function [31:0] get_imem_resp_data;
        /*verilator public*/
        get_imem_resp_data = imem_resp_data_i;
    endfunction

    function [7:0] get_imem_req_vld;
        /*verilator public*/
        get_imem_req_vld = 8'(imem_req_vld_o);
    endfunction

    function [31:0] get_imem_req_addr;
        /*verilator public*/
        get_imem_req_addr = imem_req_addr_o;
    endfunction

    function [31:0] get_if_dec_insn_data;
        /*verilator public*/
        get_if_dec_insn_data = ifetch_insn_data_q;
    endfunction

    function [31:0] get_if_dec_insn_pc;
        /*verilator public*/
        get_if_dec_insn_pc = ifetch_insn_pc_q;
    endfunction

    function [7:0] get_if_dec_insn_vld;
        /*verilator public*/
        get_if_dec_insn_vld = 8'(ifetch_insn_vld_q);
    endfunction

    function [31:0] get_ifetch_insn_data;
        /*verilator public*/
        get_ifetch_insn_data = ifetch_insn_data_lo;
    endfunction

    function [7:0] get_ifetch_insn_vld;
        /*verilator public*/
        get_ifetch_insn_vld = 8'(ifetch_insn_vld_lo);
    endfunction

    function [31:0] get_ifetch_insn_pc;
        /*verilator public*/
        get_ifetch_insn_pc = ifetch_insn_pc_lo;
    endfunction

    function [7:0] get_wb_rd_addr;
        /*verilator public*/
        get_wb_rd_addr = 8'(wb_rd_addr_lo);
    endfunction

    function [31:0] get_wb_data;
        /*verilator public*/
        get_wb_data = wb_data_lo;
    endfunction

    function [7:0] get_wb_data_vld;
        /*verilator public*/
        get_wb_data_vld = {7'b0, wb_data_vld_lo};
    endfunction

    function [7:0] get_idecode_issue_vld;
        /*verilator public*/
        get_idecode_issue_vld = {7'b0, idecode_issue_vld_lo};
    endfunction

    function [7:0] get_idecode_itag;
        /*verilator public*/
        get_idecode_itag = 8'(idecode_itag_lo);
    endfunction

    function [7:0] get_ret_retire_cnt;
        /*verilator public*/
        get_ret_retire_cnt = 8'(ret_retire_cnt_lo);
    endfunction

    function [7:0] get_iq_retire_itag;
        /*verilator public*/
        get_iq_retire_itag = 8'(iq_retire_itag_lo);
    endfunction

/*
    logic                           ifetch_insn_compressed_lo;
    logic                           ifetch_insn_illegal_lo;
*/

endmodule
