module xrv1_lsu
    import xrv1_pkg::*;
#(
    parameter ITAG_WIDTH_P = "inv"
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                        clk_i,
    input  logic                        rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic                        lsu_rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    // Data memory interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                        dmem_req_vld_o,
    input  logic                        dmem_req_rdy_i,
    input  logic                        dmem_resp_err_i,
    output logic [31:0]                 dmem_req_addr_o,
    output logic                        dmem_req_w_en_o,
    output logic [3:0]                  dmem_req_w_be_o,
    output logic [31:0]                 dmem_req_w_data_o,
    input  logic                        dmem_resp_vld_i,
    input  logic [31:0]                 dmem_resp_r_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    // LSU request
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                        lsu_req_vld_i,
    input  logic                        lsu_req_w_en_i,
    input  logic [31:0]                 lsu_req_addr_base_i,
    input  logic [31:0]                 lsu_req_addr_offset_i,
    input  logic [1:0]                  lsu_req_size_i,
    input  logic                        lsu_req_signed_i,
    input  logic [31:0]                 lsu_req_w_data_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Write back interface
    ////////////////////////////////////////////////////////////////////////////////
    output logic                        lsu_done_o,
    output logic [31:0]                 lsu_wb_data_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [ITAG_WIDTH_P-1:0]      lsu_itag_i,
    output logic [ITAG_WIDTH_P-1:0]     lsu_itag_o
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    wire dmem_req_accept_w = dmem_req_rdy_i & dmem_req_vld_o;
    wire lsu_accept_w = lsu_req_vld_i & lsu_rdy_o;

    ////////////////////////////////////////////////////////////////////////////////
    // LSU request address calculation
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] lsu_req_addr_w = lsu_req_addr_base_i + lsu_req_addr_offset_i;
    wire [31:0] lsu_req_addr_algn_w = {lsu_req_addr_w[31:2], 2'b00};
    wire [1:0]  lsu_req_offset_w = lsu_req_addr_w[1:0];

    ////////////////////////////////////////////////////////////////////////////////
    // Check whether access is unaligned
    ////////////////////////////////////////////////////////////////////////////////
    wire         w_ls_acc_w = lsu_req_size_i == LS_W;
    wire         h_ls_acc_w = lsu_req_size_i == LS_H;
    wire         b_ls_acc_w = lsu_req_size_i == LS_B;
    ////////////////////////////////////////////////////////////////////////////////
    wire         unaligned_w_acc_w = w_ls_acc_w & lsu_req_addr_w[1:0] != 2'b00;
    wire         unaligned_h_acc_w = h_ls_acc_w & lsu_req_addr_w[1:0] == 2'b11;
    wire         unaligned_acc_w = unaligned_w_acc_w | unaligned_h_acc_w;
    wire [1:0]   num_sub_resp_w = unaligned_acc_w ? 2'b10 : 2'b01;
    wire [1:0]   num_sub_req_w = num_sub_resp_w - dmem_req_accept_w;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // DMEM request
    ////////////////////////////////////////////////////////////////////////////////
    logic                       req_w_en_0_q;
    logic [31:0]                req_w_data_0_q;
    logic [1:0]                 req_size_0_q;
    logic                       req_signed_0_q;
    logic [31:0]                req_addr_0_q;
    logic [1:0]                 req_offset_0_q;
    logic                       req_unalgn_0_q;
    logic [ITAG_WIDTH_P-1:0]    req_itag_0_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic                       req_w_en_1_q;
    logic [1:0]                 req_size_1_q;
    logic                       req_signed_1_q;
    logic [1:0]                 req_offset_1_q;
    logic                       req_unalgn_1_q;
    logic [ITAG_WIDTH_P-1:0]    req_itag_1_q;
    ////////////////////////////////////////////////////////////////////////////////
    logic [1:0]                 n_req_q, n_req_n_r;
    logic [1:0]                 n_resp_q, n_resp_n_r;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (lsu_accept_w & num_sub_req_w == '0) begin
            req_w_en_1_q   <= lsu_req_w_en_i;
            req_size_1_q   <= lsu_req_size_i;
            req_signed_1_q <= lsu_req_signed_i;
            req_offset_1_q <= lsu_req_offset_w;
            req_unalgn_1_q <= unaligned_acc_w;
            req_itag_1_q   <= lsu_itag_i;
        end
        else if (lsu_accept_w) begin
            req_w_en_0_q   <= lsu_req_w_en_i;
            req_w_data_0_q <= lsu_req_w_data_i;
            req_size_0_q   <= lsu_req_size_i;
            req_signed_0_q <= lsu_req_signed_i;
            req_addr_0_q   <= lsu_req_addr_algn_w;
            req_offset_0_q <= lsu_req_offset_w;
            req_unalgn_0_q <= unaligned_acc_w;
            req_itag_0_q   <= lsu_itag_i;
        end
        else if (n_req_q != '0 & n_req_n_r == '0) begin
            req_w_en_1_q   <= req_w_en_0_q;
            req_size_1_q   <= req_size_0_q;
            req_signed_1_q <= req_signed_0_q;
            req_offset_1_q <= req_offset_0_q;
            req_unalgn_1_q <= req_unalgn_0_q;
            req_itag_1_q   <= req_itag_0_q;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            n_req_q  <= 'b0;
            n_resp_q <= 'b0;
        end
        else begin
            n_req_q  <= n_req_n_r;
            n_resp_q <= n_resp_n_r;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        n_req_n_r = n_req_q;
        n_resp_n_r = n_resp_q;
        if (lsu_accept_w) begin
            n_req_n_r  = num_sub_req_w;
            n_resp_n_r = num_sub_resp_w;
        end
        else begin
            if (dmem_req_accept_w)
                n_req_n_r = n_req_q - 1'b1;
            if (dmem_resp_vld_i)
                n_resp_n_r = n_resp_q - 1'b1;
        end
    end

    logic        req_w_en_r;
    logic [1:0]  req_size_r;
    logic [1:0]  req_offset_r;
    logic [31:0] req_w_data_r;

    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        if (lsu_accept_w) begin
            req_size_r   = lsu_req_size_i;
            req_offset_r = lsu_req_offset_w;
            req_w_data_r = lsu_req_w_data_i;
        end
        else begin
            req_size_r   = req_size_0_q;
            req_offset_r = req_offset_0_q;
            req_w_data_r = req_w_data_0_q;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // DMEM read response
    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0] dmem_resp_data_q;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (dmem_resp_vld_i) begin
            dmem_resp_data_q <= dmem_resp_r_data_i;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Read data alignment
    ////////////////////////////////////////////////////////////////////////////////
    wire [63:0]              dmem_unalgn_resp_data_w = {dmem_resp_r_data_i, dmem_resp_data_q};
    logic [31:0]             dmem_resp_data_r;
    always_comb begin
        if (req_unalgn_1_q) begin
            case (req_offset_1_q)
                2'b00: dmem_resp_data_r = dmem_unalgn_resp_data_w[31:0];
                2'b01: dmem_resp_data_r = dmem_unalgn_resp_data_w[39:8];
                2'b10: dmem_resp_data_r = dmem_unalgn_resp_data_w[47:16];
                2'b11: dmem_resp_data_r = dmem_unalgn_resp_data_w[55:24];
            endcase
        end
        else begin
            case (req_offset_1_q)
                2'b00: dmem_resp_data_r = 32'(dmem_resp_r_data_i[31:0]);
                2'b01: dmem_resp_data_r = 32'(dmem_resp_r_data_i[31:8]);
                2'b10: dmem_resp_data_r = 32'(dmem_resp_r_data_i[31:16]);
                2'b11: dmem_resp_data_r = 32'(dmem_resp_r_data_i[31:24]);
            endcase
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    logic [31:0] wb_data_sext_r;
    logic [31:0] wb_data_zext_r;
    ////////////////////////////////////////////////////////////////////////////////
    // Load data sign-extension
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (req_size_1_q)
            LS_B: wb_data_sext_r = {{24{dmem_resp_data_r[7]}}, dmem_resp_data_r[7:0]};
            LS_H: wb_data_sext_r = {{16{dmem_resp_data_r[15]}}, dmem_resp_data_r[15:0]};
            LS_W: wb_data_sext_r = dmem_resp_data_r;
            default: wb_data_sext_r = dmem_resp_data_r;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    // Load data zero-extension
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case (req_size_1_q)
            LS_B: wb_data_zext_r = {24'd0, dmem_resp_data_r[7:0]};
            LS_H: wb_data_zext_r = {16'd0, dmem_resp_data_r[15:0]};
            LS_W: wb_data_zext_r = dmem_resp_data_r;
            default: wb_data_zext_r = dmem_resp_data_r;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    assign lsu_wb_data_o = req_signed_1_q ? wb_data_sext_r : wb_data_zext_r;
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Write data alignment
    ////////////////////////////////////////////////////////////////////////////////
    logic [63:0] req_full_w_data_r;
    always_comb begin
        case (req_offset_r)
            2'b00:   req_full_w_data_r = {32'd0, req_w_data_r};
            2'b01:   req_full_w_data_r = {24'd0, req_w_data_r, 8'd0};
            2'b10:   req_full_w_data_r = {16'd0, req_w_data_r, 16'd0};
            2'b11:   req_full_w_data_r = {8'd0,  req_w_data_r, 24'd0};
            default: req_full_w_data_r = {32'd0, req_w_data_r};
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Byte-enable generation
    ////////////////////////////////////////////////////////////////////////////////
    logic [3:0]  dmem_req_be_0_r;
    logic [3:0]  dmem_req_be_1_r;
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case ({req_offset_r, req_size_r})
            ////////////////////////////////////////////////////////////////////////////////
            {2'b00, LS_W}: dmem_req_be_0_r = 4'b1111;
            {2'b01, LS_W}: dmem_req_be_0_r = 4'b1110;
            {2'b10, LS_W}: dmem_req_be_0_r = 4'b1100;
            {2'b11, LS_W}: dmem_req_be_0_r = 4'b1000;
            ////////////////////////////////////////////////////////////////////////////////
            {2'b00, LS_H}: dmem_req_be_0_r = 4'b0011;
            {2'b01, LS_H}: dmem_req_be_0_r = 4'b0110;
            {2'b10, LS_H}: dmem_req_be_0_r = 4'b1100;
            {2'b11, LS_H}: dmem_req_be_0_r = 4'b1000;
            ////////////////////////////////////////////////////////////////////////////////
            {2'b00, LS_B}: dmem_req_be_0_r = 4'b0001;
            {2'b01, LS_B}: dmem_req_be_0_r = 4'b0010;
            {2'b10, LS_B}: dmem_req_be_0_r = 4'b0100;
            {2'b11, LS_B}: dmem_req_be_0_r = 4'b1000;
            default: dmem_req_be_0_r       = 4'b0000;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        case ({req_offset_r, req_size_r})
            ////////////////////////////////////////////////////////////////////////////////
            {2'b01, LS_W}: dmem_req_be_1_r = 4'b0001;
            {2'b10, LS_W}: dmem_req_be_1_r = 4'b0011;
            {2'b11, LS_W}: dmem_req_be_1_r = 4'b0111;
            ////////////////////////////////////////////////////////////////////////////////
            {2'b11, LS_H}: dmem_req_be_1_r = 4'b0001;
            default: dmem_req_be_1_r       = 4'b0000;
        endcase
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // DMEM interface control
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        ////////////////////////////////////////////////////////////////////////////////
        dmem_req_w_en_o = 1'b0;
        dmem_req_vld_o  = 1'b0;
        ////////////////////////////////////////////////////////////////////////////////
        if (lsu_accept_w) begin
            dmem_req_addr_o   = lsu_req_addr_algn_w;
            dmem_req_w_be_o   = dmem_req_be_0_r;
            dmem_req_w_data_o = req_full_w_data_r[31:0];
            dmem_req_w_en_o   = lsu_req_w_en_i;
            dmem_req_vld_o    = 1'b1;
        end
        else if (req_unalgn_0_q & n_req_q == 2'b01) begin
            dmem_req_addr_o   = req_addr_0_q + 'd4;
            dmem_req_w_be_o   = dmem_req_be_1_r;
            dmem_req_w_data_o = req_full_w_data_r[63:32];
            dmem_req_w_en_o   = req_w_en_0_q;
            dmem_req_vld_o    = 1'b1;
        end
        else begin
            dmem_req_addr_o   = req_addr_0_q;
            dmem_req_w_be_o   = dmem_req_be_0_r;
            dmem_req_w_data_o = req_full_w_data_r[31:0];
            dmem_req_w_en_o   = req_w_en_0_q;
            dmem_req_vld_o    = n_req_q != '0;
        end
    end
    ///////////////////////////////////////////////////////////////////////////////
    assign lsu_itag_o = req_itag_1_q;
    assign lsu_rdy_o  = (n_req_q == 2'b00) | ((n_req_q == 2'b01) & dmem_req_rdy_i);
    assign lsu_done_o = (n_resp_q == 2'b01) & dmem_resp_vld_i;
    ////////////////////////////////////////////////////////////////////////////////
    always_comb begin
        if (dmem_req_vld_o)
            $display("w_en=%h addr=%h req_w_data=%h itag=%d",
                dmem_req_w_en_o, dmem_req_addr_o, dmem_req_w_data_o, lsu_itag_i);
        if (dmem_resp_vld_i)
            $display("resp_data=%h n_resp=%d lsu_done_o=%d", dmem_resp_r_data_i, n_resp_q, lsu_done_o);
    end

endmodule