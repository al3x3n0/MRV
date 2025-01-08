module mrv1_mem_queue
#(
    parameter XLEN_P = 32,
    parameter ADDR_WIDTH_P = XLEN_P,
    parameter DATA_WIDTH_P = XLEN_P,
    parameter NUM_THREADS_P = "inv",
    parameter ITAG_WIDTH_P = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter DATA_BE_WIDTH_P = DATA_WIDTH_P >> 3,
    parameter QUEUE_SIZE_LP = (1 << ITAG_WIDTH_P),
    parameter TID_WIDTH_LP = $clog2(NUM_THREADS_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                             clk_i,
    input logic                             rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                            lsu_req_vld_i,
    input  logic                            lsu_req_w_en_i,
    input  logic [ADDR_WIDTH_P-1:0]         lsu_req_addr_i,
    input  logic [1:0]                      lsu_req_size_i,
    input  logic [1:0]                      lsu_req_offset_i,
    input  logic                            lsu_req_unalgn_i,
    input  logic                            lsu_req_signed_i,
    input  logic [DATA_WIDTH_P-1:0]         lsu_req_w_data_i,
    input  logic [ITAG_WIDTH_P-1:0]         lsu_req_itag_i,
    //////////////////////////////////////////////////////////
    input  logic                            dmem_req_rdy_i,
    output logic                            dmem_req_vld_o,
    output logic [ADDR_WIDTH_P-1:0]         dmem_req_addr_o,
    output logic                            dmem_req_wnr_o,
    output logic [ITAG_WIDTH_P-1:0]         dmem_req_itag_o,
    output logic [DATA_BE_WIDTH_P-1:0]      dmem_req_w_be_o,
    output logic [DATA_WIDTH_P-1:0]         dmem_req_w_data_o,
    //////////////////////////////////////////////////////////
    input  logic                            dmem_resp_vld_i,
    input  logic [ITAG_WIDTH_P-1:0]         dmem_resp_itag_i,
    input  logic [DATA_WIDTH_P-1:0]         dmem_resp_r_data_i,
    //////////////////////////////////////////////////////////
    output logic                            mem_sched_req_rdy_o,
    input  logic                            mem_sched_req_vld_i,
    //////////////////////////////////////////////////////////
    output logic [DATA_WIDTH_P-1:0]         mem_commit_data_o,
    output logic [ITAG_WIDTH_P-1:0]         mem_commit_itag_o,
    output logic                            mem_commit_rdy_o,
    input  logic                            mem_commit_vld_i
);
    //////////////////////////////////////////////////////////
    logic [ITAG_WIDTH_P:0]      mq_sz_r, mq_sz_n_r;
    logic [ITAG_WIDTH_P-1:0]    req_ptr_r, req_ptr_n;
    logic [ITAG_WIDTH_P-1:0]    resp_ptr_r, resp_ptr_n;
    //////////////////////////////////////////////////////////
    // Mem queue data
    //////////////////////////////////////////////////////////
    logic [QUEUE_SIZE_LP-1:0]                       req_vld_q, req_vld_n;
    logic [QUEUE_SIZE_LP-1:0]                       req_wnr_q;
    logic [QUEUE_SIZE_LP-1:0]                       req_p0_sent_q, req_p0_sent_n;
    logic [QUEUE_SIZE_LP-1:0]                       req_signed_q;
    logic [QUEUE_SIZE_LP-1:0]                       req_unalgn_q;
    logic [QUEUE_SIZE_LP-1:0][1:0]                  req_offset_q;
    logic [QUEUE_SIZE_LP-1:0][1:0]                  req_size_q;
    logic [QUEUE_SIZE_LP-1:0][ADDR_WIDTH_P-1:0]     req_addr_q;
    logic [QUEUE_SIZE_LP-1:0][DATA_WIDTH_P-1:0]     req_w_data_q;
    //////////////////////////////////////////////////////////
    logic [QUEUE_SIZE_LP-1:0]                       resp_data0_vld_q, resp_data0_vld_n;
    logic [QUEUE_SIZE_LP-1:0]                       resp_data1_vld_q, resp_data1_vld_n;
    logic [QUEUE_SIZE_LP-1:0][DATA_WIDTH_P-1:0]     resp_data0_q;
    logic [QUEUE_SIZE_LP-1:0][DATA_WIDTH_P-1:0]     resp_data1_q;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            req_ptr_r           <= 'b0;
            resp_ptr_r          <= 'b0;
            mq_sz_r             <= 'b0;
        end
        else begin
            req_ptr_r           <= req_ptr_n;
            resp_ptr_r          <= resp_ptr_n;
            mq_sz_r             <= mq_sz_n_r;
            req_p0_sent_q       <= req_p0_sent_n;
        end
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Queue management
    ////////////////////////////////////////////////////////////////////////////////
    logic                       req_p0_sent_w       = req_p0_sent_q[req_ptr_r]; 
    logic                       req_unalgn_w        = req_unalgn_q[req_ptr_r];
    logic [1:0]                 req_offset_w        = req_offset_q[req_ptr_r];
    logic [1:0]                 req_size_w          = req_size_q[req_ptr_r];
    logic [ADDR_WIDTH_P-1:0]    req_addr_w          = req_addr_q[req_ptr_r];
    logic [DATA_WIDTH_P-1:0]    req_w_data_w        = req_w_data_q[req_ptr_r];
    ////////////////////////////////////////////////////////////////////////////////
    logic [1:0]                 resp_size_w         = req_size_q[resp_ptr_r];
    logic                       resp_signed_w       = req_signed_q[resp_ptr_r];
    logic [1:0]                 resp_offset_w       = req_offset_q[resp_ptr_r];
    logic                       resp_unalgn_w       = req_unalgn_q[resp_ptr_r];
    logic [DATA_WIDTH_P-1:0]    resp_data0_w        = resp_data0_q[resp_ptr_r];
    logic [DATA_WIDTH_P-1:0]    resp_data1_w        = resp_data1_q[resp_ptr_r];
    ////////////////////////////////////////////////////////////////////////////////
    logic dmem_req_accept_w = dmem_req_rdy_i && dmem_req_vld_o && mem_sched_req_vld_i;
    always_comb begin
        mq_sz_n_r           = mq_sz_r;
        req_ptr_n           = req_ptr_r;
        resp_ptr_n          = resp_ptr_r;
        ////////////////////////////////////////////////////////////////////////////////
        req_vld_n           = req_vld_q;
        resp_data0_vld_n    = resp_data0_vld_q;
        resp_data1_vld_n    = resp_data1_vld_q;
        req_p0_sent_n       = req_p0_sent_q;
        if (mem_commit_vld_i) begin
            req_vld_n[resp_ptr_n] = 1'b0;
            resp_data0_vld_n[resp_ptr_n] = 1'b0;
            resp_data1_vld_n[resp_ptr_n] = 1'b0;
            resp_ptr_n = resp_ptr_n + 1'b1;
            mq_sz_n_r = mq_sz_n_r - 1'b1;
        end
        ////////////////////////////////////////////////////////////////////////////////
        if (lsu_req_vld_i) begin
            req_vld_n[lsu_req_itag_i]           = 1'b1;
            req_p0_sent_n[lsu_req_itag_i]       = 1'b0;
            resp_data0_vld_n[lsu_req_itag_i]    = 1'b0;
            resp_data1_vld_n[lsu_req_itag_i]    = 1'b0;
        end
        ////////////////////////////////////////////////////////////////////////////////
        if (dmem_resp_vld_i) begin
            if (req_unalgn_q[dmem_resp_itag_i]) begin
                if (resp_data0_vld_n[dmem_resp_itag_i]) begin
                    resp_data1_vld_n[dmem_resp_itag_i] = 1'b1;
                end else begin
                    resp_data0_vld_n[dmem_resp_itag_i] = 1'b1;
                end
            end else begin
                resp_data0_vld_n[dmem_resp_itag_i] = 1'b1;
            end
        end
        ////////////////////////////////////////////////////////////////////////////////
        if (dmem_req_accept_w) begin
            if (req_unalgn_w) begin
                if (req_p0_sent_w) begin
                    req_ptr_n = req_ptr_n + 1'b1;
                    mq_sz_n_r = mq_sz_n_r + 1'b1;
                end else begin
                    req_p0_sent_n[resp_ptr_n] = 1'b1;
                end
            end else begin
                req_ptr_n = req_ptr_n + 1'b1;
                mq_sz_n_r = mq_sz_n_r + 1'b1;
            end
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    // Request
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (lsu_req_vld_i) begin
            req_wnr_q[lsu_req_itag_i]       <= lsu_req_w_en_i;
            req_signed_q[lsu_req_itag_i]    <= lsu_req_signed_i;
            req_unalgn_q[lsu_req_itag_i]    <= lsu_req_unalgn_i;
            req_offset_q[lsu_req_itag_i]    <= lsu_req_offset_i;
            req_size_q[lsu_req_itag_i]      <= lsu_req_size_i;
            req_addr_q[lsu_req_itag_i]      <= lsu_req_addr_i;
            req_w_data_q[lsu_req_itag_i]    <= lsu_req_w_data_i;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    // Response
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (dmem_resp_vld_i) begin
            if (req_unalgn_q[dmem_resp_itag_i]) begin
                if (resp_data0_vld_q[dmem_resp_itag_i]) begin
                    resp_data1_q[dmem_resp_itag_i]      <= dmem_resp_r_data_i;
                end else begin
                    resp_data0_q[dmem_resp_itag_i]      <= dmem_resp_r_data_i;
                end
            end else begin
                resp_data0_q[dmem_resp_itag_i]          <= dmem_resp_r_data_i;
            end
        end
    end

    logic mem_commit_rdy_2 = ~resp_unalgn_w || (resp_unalgn_w && resp_data1_vld_q[resp_ptr_n]);
    assign mem_commit_rdy_o = req_vld_q[resp_ptr_n] && resp_data0_vld_q[resp_ptr_n] && mem_commit_rdy_2;

    ////////////////////////////////////////////////////////////////////////////////
    // Read data alignment
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P*2-1:0] dmem_unalgn_resp_data_w = {resp_data0_w, resp_data1_w};
    logic [DATA_WIDTH_P-1:0] dmem_resp_data_r;
    always_comb begin
        if (resp_unalgn_w) begin
            case (resp_offset_w)
                2'b00: dmem_resp_data_r = dmem_unalgn_resp_data_w[31:0];
                2'b01: dmem_resp_data_r = dmem_unalgn_resp_data_w[39:8];
                2'b10: dmem_resp_data_r = dmem_unalgn_resp_data_w[47:16];
                2'b11: dmem_resp_data_r = dmem_unalgn_resp_data_w[55:24];
            endcase
        end
        else begin
            case (resp_offset_w)
                2'b00: dmem_resp_data_r = DATA_WIDTH_P'(dmem_unalgn_resp_data_w[31:0]);
                2'b01: dmem_resp_data_r = DATA_WIDTH_P'(dmem_unalgn_resp_data_w[31:8]);
                2'b10: dmem_resp_data_r = DATA_WIDTH_P'(dmem_unalgn_resp_data_w[31:16]);
                2'b11: dmem_resp_data_r = DATA_WIDTH_P'(dmem_unalgn_resp_data_w[31:24]);
            endcase
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    // Load data sign-extension
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0] wb_data_sext_r;
    logic [DATA_WIDTH_P-1:0] wb_data_zext_r;
    always_comb begin
        case (resp_size_w)
            LS_B: wb_data_sext_r    = {{24{dmem_resp_data_r[7]}}, dmem_resp_data_r[7:0]};
            LS_H: wb_data_sext_r    = {{16{dmem_resp_data_r[15]}}, dmem_resp_data_r[15:0]};
            LS_W: wb_data_sext_r    = dmem_resp_data_r;
            default: wb_data_sext_r = dmem_resp_data_r;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    // Load data zero-extension
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (resp_size_w)
            LS_B: wb_data_zext_r = {24'd0, dmem_resp_data_r[7:0]};
            LS_H: wb_data_zext_r = {16'd0, dmem_resp_data_r[15:0]};
            LS_W: wb_data_zext_r = dmem_resp_data_r;
            default: wb_data_zext_r = dmem_resp_data_r;
        endcase
    end
    assign mem_commit_data_o = resp_signed_w ? wb_data_sext_r : wb_data_zext_r;
    assign mem_commit_itag_o = resp_ptr_r;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Write data alignment
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P*2-1:0] req_full_w_data_r;
    always_comb begin
        case (req_offset_w)
            2'b00:   req_full_w_data_r = {32'd0, req_w_data_w};
            2'b01:   req_full_w_data_r = {24'd0, req_w_data_w, 8'd0};
            2'b10:   req_full_w_data_r = {16'd0, req_w_data_w, 16'd0};
            2'b11:   req_full_w_data_r = {8'd0,  req_w_data_w, 24'd0};
            default: req_full_w_data_r = {32'd0, req_w_data_w};
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    // Byte-enable generation
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_BE_WIDTH_P-1:0]  dmem_req_be_0_r;
    logic [DATA_BE_WIDTH_P-1:0]  dmem_req_be_1_r;
    always_comb begin
        case ({req_offset_w, req_size_w})
            {2'b00, LS_W}: dmem_req_be_0_r = 4'b1111;
            {2'b01, LS_W}: dmem_req_be_0_r = 4'b1110;
            {2'b10, LS_W}: dmem_req_be_0_r = 4'b1100;
            {2'b11, LS_W}: dmem_req_be_0_r = 4'b1000;
            {2'b00, LS_H}: dmem_req_be_0_r = 4'b0011;
            {2'b01, LS_H}: dmem_req_be_0_r = 4'b0110;
            {2'b10, LS_H}: dmem_req_be_0_r = 4'b1100;
            {2'b11, LS_H}: dmem_req_be_0_r = 4'b1000;
            {2'b00, LS_B}: dmem_req_be_0_r = 4'b0001;
            {2'b01, LS_B}: dmem_req_be_0_r = 4'b0010;
            {2'b10, LS_B}: dmem_req_be_0_r = 4'b0100;
            {2'b11, LS_B}: dmem_req_be_0_r = 4'b1000;
            default: dmem_req_be_0_r       = 4'b0000;
        endcase
    end
    always_comb begin
        case ({req_offset_w, req_size_w})
            {2'b01, LS_W}: dmem_req_be_1_r = 4'b0001;
            {2'b10, LS_W}: dmem_req_be_1_r = 4'b0011;
            {2'b11, LS_W}: dmem_req_be_1_r = 4'b0111;
            {2'b11, LS_H}: dmem_req_be_1_r = 4'b0001;
            default: dmem_req_be_1_r       = 4'b0000;
        endcase
    end
    assign dmem_req_vld_o       = req_vld_q[req_ptr_r];
    assign dmem_req_wnr_o       = req_wnr_q[req_ptr_r];
    assign dmem_req_addr_o      = req_p0_sent_w ? (req_addr_w + 'd4) : req_addr_w; // FIXME
    assign dmem_req_w_be_o      = req_p0_sent_w ? dmem_req_be_1_r : dmem_req_be_0_r;
    assign dmem_req_w_data_o    = req_p0_sent_w ? req_full_w_data_r[DATA_WIDTH_P*2-1:DATA_WIDTH_P] : req_full_w_data_r[DATA_WIDTH_P-1:0];
    ////////////////////////////////////////////////////////////////////////////////

endmodule