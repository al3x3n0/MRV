`include "pkg/xm_rv_pkg.sv"

module mrv1_mem_queue
    import xm_rv_pkg::*;
#(
    parameter XLEN_P = 32,
    parameter NUM_THREADS_P = "inv",
    parameter ITAG_WIDTH_P = "inv"
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                             clk_i,
    input logic                             rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                            lsu_req_vld_i,
    input  logic                            lsu_req_w_en_i,
    input  logic [ADDR_WIDTH_P-1:0]         lsu_req_addr_i,
    input  logic [1:0]                      lsu_req_size_i,
    input  logic [DATA_BE_WIDTH_LOG-1:0]    lsu_req_offset_i,
    input  logic                            lsu_req_unalgn_i,
    input  logic                            lsu_req_signed_i,
    input  logic [DATA_WIDTH_P-1:0]         lsu_req_w_data_i,
    input  logic [ITAG_WIDTH_P-1:0]         lsu_req_itag_i,
    //////////////////////////////////////////////////////////
    input  logic                            dmem_req_rdy_i,
    output logic                            dmem_req_vld_o,
    output logic [XLEN_P-1:0]               dmem_req_addr_o,
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
    localparam ADDR_WIDTH_P = XLEN_P;
    localparam DATA_WIDTH_P = XLEN_P;
    localparam DATA_BE_WIDTH_P = DATA_WIDTH_P >> 3;
    localparam DATA_BE_WIDTH_LOG = $clog2(DATA_BE_WIDTH_P);
    localparam QUEUE_SIZE_LP = (1 << ITAG_WIDTH_P);
    localparam TID_WIDTH_LP = $clog2(NUM_THREADS_P);

    //////////////////////////////////////////////////////////
    logic [ITAG_WIDTH_P:0]      mq_sz_r, mq_sz_n_r;
    logic [ITAG_WIDTH_P-1:0]    head_ptr_r, head_ptr_n;
    logic [ITAG_WIDTH_P-1:0]    commit_ptr_r, commit_ptr_n;
    logic [ITAG_WIDTH_P-1:0]    req_ptr_r, req_ptr_n;
    //////////////////////////////////////////////////////////
    // Mem queue data
    //////////////////////////////////////////////////////////
    logic [QUEUE_SIZE_LP-1:0]                       req_vld_q, req_vld_n;
    logic [QUEUE_SIZE_LP-1:0]                       req_wnr_q;
    logic [QUEUE_SIZE_LP-1:0]                       req_p0_sent_q, req_p0_sent_n;
    logic [QUEUE_SIZE_LP-1:0]                       req_signed_q;
    logic [QUEUE_SIZE_LP-1:0]                       req_unalgn_q;
    logic [QUEUE_SIZE_LP-1:0][DATA_BE_WIDTH_LOG-1:0]req_offset_q;
    logic [QUEUE_SIZE_LP-1:0][1:0]                  req_size_q;
    logic [QUEUE_SIZE_LP-1:0][ADDR_WIDTH_P-1:0]     req_addr_q;
    logic [QUEUE_SIZE_LP-1:0][DATA_WIDTH_P-1:0]     req_w_data_q;
    logic [QUEUE_SIZE_LP-1:0][ITAG_WIDTH_P-1:0]     req_itag_q;
    //////////////////////////////////////////////////////////
    logic [QUEUE_SIZE_LP-1:0]                       resp_data0_vld_q, resp_data0_vld_n;
    logic [QUEUE_SIZE_LP-1:0]                       resp_data1_vld_q, resp_data1_vld_n;
    logic [QUEUE_SIZE_LP-1:0][DATA_WIDTH_P-1:0]     resp_data0_q;
    logic [QUEUE_SIZE_LP-1:0][DATA_WIDTH_P-1:0]     resp_data1_q;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            head_ptr_r          <= '0;
            commit_ptr_r          <= '0;
            req_ptr_r           <= '0;
            mq_sz_r             <= '0;
            req_vld_q           <= '0;
            resp_data0_vld_q    <= '0;
            resp_data1_vld_q    <= '0;
        end
        else begin
            head_ptr_r          <= head_ptr_n;
            commit_ptr_r          <= commit_ptr_n;
            req_ptr_r           <= req_ptr_n;
            mq_sz_r             <= mq_sz_n_r;
            req_p0_sent_q       <= req_p0_sent_n;
            req_vld_q           <= req_vld_n;
            resp_data0_vld_q    <= resp_data0_vld_n;
            resp_data1_vld_q    <= resp_data1_vld_n;
        end
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Queue management
    ////////////////////////////////////////////////////////////////////////////////
    wire                       req_p0_sent_w       = req_p0_sent_q[req_ptr_r]; 
    wire                       req_unalgn_w        = req_unalgn_q[req_ptr_r];
    wire [DATA_BE_WIDTH_LOG-1:0] req_offset_w        = req_offset_q[req_ptr_r];
    wire [1:0]                 req_size_w          = req_size_q[req_ptr_r];
    wire [ADDR_WIDTH_P-1:0]    req_addr_w          = req_addr_q[req_ptr_r];
    wire [DATA_WIDTH_P-1:0]    req_w_data_w        = req_w_data_q[req_ptr_r];
    ////////////////////////////////////////////////////////////////////////////////
    wire [1:0]                 resp_size_w         = req_size_q[commit_ptr_r];
    wire                       resp_signed_w       = req_signed_q[commit_ptr_r];
    wire [DATA_BE_WIDTH_LOG-1:0] resp_offset_w       = req_offset_q[commit_ptr_r];
    wire                       resp_unalgn_w       = req_unalgn_q[commit_ptr_r];
    wire [DATA_WIDTH_P-1:0]    resp_data0_w        = resp_data0_q[commit_ptr_r];
    wire [DATA_WIDTH_P-1:0]    resp_data1_w        = resp_data1_q[commit_ptr_r];
    ////////////////////////////////////////////////////////////////////////////////
    wire dmem_req_accept_w = dmem_req_rdy_i && dmem_req_vld_o && mem_sched_req_vld_i;
    always_comb begin
        mq_sz_n_r           = mq_sz_r;
        head_ptr_n          = head_ptr_r;
        commit_ptr_n          = commit_ptr_r;
        req_ptr_n          = req_ptr_r;
        ////////////////////////////////////////////////////////////////////////////////
        req_vld_n           = req_vld_q;
        resp_data0_vld_n    = resp_data0_vld_q;
        resp_data1_vld_n    = resp_data1_vld_q;
        req_p0_sent_n       = req_p0_sent_q;
        if (mem_commit_vld_i) begin
            req_vld_n[commit_ptr_n] = 1'b0;
            resp_data0_vld_n[commit_ptr_n] = 1'b0;
            resp_data1_vld_n[commit_ptr_n] = 1'b0;
            commit_ptr_n = commit_ptr_n + 1'b1;
            mq_sz_n_r = mq_sz_n_r - 1'b1;
        end
        ////////////////////////////////////////////////////////////////////////////////
        if (lsu_req_vld_i) begin
            req_vld_n[head_ptr_n]           = 1'b1;
            req_p0_sent_n[head_ptr_n]       = 1'b0;
            resp_data0_vld_n[head_ptr_n]    = 1'b0;
            resp_data1_vld_n[head_ptr_n]    = 1'b0;
            head_ptr_n = head_ptr_n + 1'b1;
            mq_sz_n_r = mq_sz_n_r + 1'b1;
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
                    if (req_wnr_q[req_ptr_n]) begin
                        resp_data1_vld_n[req_ptr_n] = 1'b1;
                    end
                    req_ptr_n = req_ptr_n + 1'b1;
                end else begin
                    if (req_wnr_q[req_ptr_n]) begin
                        resp_data0_vld_n[req_ptr_n] = 1'b1;
                    end
                    req_p0_sent_n[req_ptr_n] = 1'b1;
                end
            end else begin
                if (req_wnr_q[req_ptr_n]) begin
                    resp_data0_vld_n[req_ptr_n] = 1'b1;
                end
                req_ptr_n = req_ptr_n + 1'b1;
            end
        end
        if (dmem_req_accept_w) begin
            $display("[MREQ] req_ptr=%h resp_ptr=%h send_ptr=%h", head_ptr_r, commit_ptr_r, req_ptr_r);
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    // Request
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (lsu_req_vld_i) begin
            req_itag_q[head_ptr_r]       <= lsu_req_itag_i;
            req_wnr_q[head_ptr_r]        <= lsu_req_w_en_i;
            req_signed_q[head_ptr_r]     <= lsu_req_signed_i;
            req_unalgn_q[head_ptr_r]     <= lsu_req_unalgn_i;
            req_offset_q[head_ptr_r]     <= (lsu_req_size_i == LS_D) ? lsu_req_offset_i : {{DATA_BE_WIDTH_LOG-2{1'b0}}, lsu_req_offset_i[1:0]};
            req_size_q[head_ptr_r]       <= lsu_req_size_i;
            req_addr_q[head_ptr_r]       <= lsu_req_addr_i;
            req_w_data_q[head_ptr_r]     <= lsu_req_w_data_i;
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

    wire mem_commit_rdy_2 = ~resp_unalgn_w || (resp_unalgn_w && resp_data1_vld_q[commit_ptr_r]);
    assign mem_commit_rdy_o = req_vld_q[commit_ptr_r] && resp_data0_vld_q[commit_ptr_r] && mem_commit_rdy_2;

    ////////////////////////////////////////////////////////////////////////////////
    // Read data alignment
    ////////////////////////////////////////////////////////////////////////////////
    wire [DATA_WIDTH_P*2-1:0] dmem_unalgn_resp_data_w = {resp_data1_w, resp_data0_w};
    logic [DATA_WIDTH_P-1:0] dmem_resp_data_tmp [0:DATA_BE_WIDTH_P-1];
    logic [DATA_WIDTH_P-1:0] dmem_resp_data_r;

    for (genvar i = 0; i < DATA_BE_WIDTH_P; i++) begin
        always_comb begin
            if (resp_unalgn_w) begin
                dmem_resp_data_tmp[i] = dmem_unalgn_resp_data_w[DATA_WIDTH_P-1 + i*8:i*8];
            end else begin
                dmem_resp_data_tmp[i] = DATA_WIDTH_P'(dmem_unalgn_resp_data_w[DATA_WIDTH_P-1:i*8]);
            end
        end
    end
    assign dmem_resp_data_r = dmem_resp_data_tmp[resp_offset_w];
    // always_comb begin
    //     if (resp_unalgn_w) begin
    //         case (resp_offset_w)
    //             2'b00: dmem_resp_data_r = dmem_unalgn_resp_data_w[DATA_WIDTH_P-1:0];
    //             2'b01: dmem_resp_data_r = dmem_unalgn_resp_data_w[DATA_WIDTH_P-1+8:8];
    //             2'b10: dmem_resp_data_r = dmem_unalgn_resp_data_w[DATA_WIDTH_P-1+16:16];
    //             2'b11: dmem_resp_data_r = dmem_unalgn_resp_data_w[DATA_WIDTH_P-1+24:24];
    //         endcase
    //         // for (int i = 0; i < DATA_BE_WIDTH_LOG; i++) begin
    //         //     dmem_resp_data_r = dmem_unalgn_resp_data_w[DATA_WIDTH_P-1 + i*8:i*8];
    //         // end
    //     end
    //     else begin
    //         case (resp_offset_w)
    //             2'b00: dmem_resp_data_r = DATA_WIDTH_P'(dmem_unalgn_resp_data_w[DATA_WIDTH_P-1:0]);
    //             2'b01: dmem_resp_data_r = DATA_WIDTH_P'(dmem_unalgn_resp_data_w[DATA_WIDTH_P-1:8]);
    //             2'b10: dmem_resp_data_r = DATA_WIDTH_P'(dmem_unalgn_resp_data_w[DATA_WIDTH_P-1:16]);
    //             2'b11: dmem_resp_data_r = DATA_WIDTH_P'(dmem_unalgn_resp_data_w[DATA_WIDTH_P-1:24]);
    //         endcase
    //     end
    // end

    //////////////////////////////////////////////////////////////////////////////
    // Load data sign-extension
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P-1:0] wb_data_sext_r;
    logic [DATA_WIDTH_P-1:0] wb_data_zext_r;
    always_comb begin
        case (resp_size_w)
            LS_B: wb_data_sext_r    = {{(DATA_WIDTH_P-8){dmem_resp_data_r[7]}}, dmem_resp_data_r[7:0]};
            LS_H: wb_data_sext_r    = {{(DATA_WIDTH_P-16){dmem_resp_data_r[15]}}, dmem_resp_data_r[15:0]};
            LS_W: wb_data_sext_r    = {{(DATA_WIDTH_P-32){dmem_resp_data_r[31]}}, dmem_resp_data_r[31:0]};
            LS_D: wb_data_sext_r    = dmem_resp_data_r;
            default: wb_data_sext_r = dmem_resp_data_r;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    // Load data zero-extension
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (resp_size_w)
            LS_B: wb_data_zext_r = {{(DATA_WIDTH_P-8){1'b0}}, dmem_resp_data_r[7:0]};
            LS_H: wb_data_zext_r = {{(DATA_WIDTH_P-16){1'b0}}, dmem_resp_data_r[15:0]};
            LS_W: wb_data_zext_r = {{(DATA_WIDTH_P-32){1'b0}}, dmem_resp_data_r[31:0]};
            LS_D: wb_data_zext_r = dmem_resp_data_r;
            default: wb_data_zext_r = dmem_resp_data_r;
        endcase
    end
    assign mem_commit_data_o = resp_signed_w ? wb_data_sext_r : wb_data_zext_r;
    assign mem_commit_itag_o = req_itag_q[commit_ptr_r];
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Write data alignment
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_WIDTH_P*2-1:0] req_full_w_data_tmp [0:DATA_BE_WIDTH_P-1];
    logic [DATA_WIDTH_P*2-1:0] req_full_w_data_r;
    // always_comb begin
    //     case (req_offset_w)
    //         2'b00:   req_full_w_data_r = {{(DATA_WIDTH_P){1'b0}}, req_w_data_w};
    //         2'b01:   req_full_w_data_r = {{(DATA_WIDTH_P-8){1'b0}}, req_w_data_w, 8'd0};
    //         2'b10:   req_full_w_data_r = {{(DATA_WIDTH_P-16){1'b0}}, req_w_data_w, 16'd0};
    //         2'b11:   req_full_w_data_r = {{(DATA_WIDTH_P-24){1'b0}},  req_w_data_w, 24'd0};
    //         default: req_full_w_data_r = {{(DATA_WIDTH_P){1'b0}}, req_w_data_w};
    //     endcase
    // end

    for (genvar i = 0; i < DATA_BE_WIDTH_P; i++) begin
        assign req_full_w_data_tmp[i] = {{(DATA_WIDTH_P-i*8){1'b0}}, req_w_data_w, {(i*8){1'b0}}};
    end
    assign req_full_w_data_r = req_full_w_data_tmp[req_offset_w];

    ////////////////////////////////////////////////////////////////////////////////
    // Byte-enable generation
    ////////////////////////////////////////////////////////////////////////////////
    logic [DATA_BE_WIDTH_P-1:0]  dmem_req_be_0_r;
    logic [DATA_BE_WIDTH_P-1:0]  dmem_req_be_1_r;
    logic [DATA_BE_WIDTH_P*2-1:0] dmem_req_be_tmp [0:DATA_BE_WIDTH_P-1][0:3];
    
    for (genvar i = 0; i < DATA_BE_WIDTH_P; i++) begin
        assign dmem_req_be_tmp[i][LS_B] = {{(DATA_BE_WIDTH_P*2-i-1){1'b0}}, 1'b1, {(i){1'b0}}};
        assign dmem_req_be_tmp[i][LS_H] = {{(DATA_BE_WIDTH_P*2-i-2){1'b0}}, 2'b11, {(i){1'b0}}};
        assign dmem_req_be_tmp[i][LS_W] = {{(DATA_BE_WIDTH_P*2-i-4){1'b0}}, 4'b1111, {(i){1'b0}}};
        if (XLEN_P == 32) begin
            assign dmem_req_be_tmp[i][LS_D] = 'h0;
        end else begin
            assign dmem_req_be_tmp[i][LS_D] = {{(DATA_BE_WIDTH_P*2-i-8){1'b0}}, 8'b11111111, {(i){1'b0}}};
        end
    end
    assign dmem_req_be_0_r = dmem_req_be_tmp[req_offset_w][req_size_w][DATA_BE_WIDTH_P-1:0];
    assign dmem_req_be_1_r = dmem_req_be_tmp[req_offset_w][req_size_w][DATA_BE_WIDTH_P*2-1:DATA_BE_WIDTH_P];

    assign dmem_req_itag_o      = req_ptr_r;
    assign dmem_req_vld_o       = req_vld_q[req_ptr_r];
    assign dmem_req_wnr_o       = req_wnr_q[req_ptr_r];
    assign dmem_req_addr_o      = req_p0_sent_w ? (req_addr_w + XLEN_P'(DATA_BE_WIDTH_P)) : req_addr_w; // FIXME
    assign dmem_req_w_be_o      = req_p0_sent_w ? dmem_req_be_1_r : dmem_req_be_0_r;
    assign dmem_req_w_data_o    = req_p0_sent_w ? req_full_w_data_r[DATA_WIDTH_P*2-1:DATA_WIDTH_P] : req_full_w_data_r[DATA_WIDTH_P-1:0];
    ////////////////////////////////////////////////////////////////////////////////

    always_comb begin
        //$display("[MEM_QUEUE] req_vld %d addr %x ", dmem_req_vld_o, dmem_req_addr_o, );
        if (dmem_resp_vld_i) begin
            $display("[MRESP] id=%h data=%h", dmem_resp_itag_i, dmem_resp_r_data_i);
        end
        if (mem_commit_vld_i) begin
            $display("[MEM->COMMIT] itag=%h id=%h data=%h buf=%h:%h tmp=%h",
                mem_commit_itag_o, commit_ptr_r, mem_commit_data_o, resp_data1_w, resp_data0_w, dmem_resp_data_r);
        end 
    end

endmodule