// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "xm_macro.svh"


`TRACING_OFF
module xrv_axi_adapter #(
    parameter DATA_WIDTH_P     = 512,
    parameter ADDR_WIDTH_IN_P  = 26, // word-addressable
    parameter ADDR_WIDTH_OUT_P = 32, // byte-addressable
    parameter TAG_WIDTH_IN_P   = 8,
    parameter TAG_WIDTH_OUT_P  = 8,
    parameter NUM_PORTS_IN_P   = 1,
    parameter NUM_BANKS_OUT_P  = 1,
    parameter INTERLEAVE_P     = 0,
    parameter TAG_BUFFER_SIZE_P= 32,
    parameter ARBITER_TYPE_P        = "R",
    parameter REQ_OUT_BUF    = 1,
    parameter RSP_OUT_BUF    = 1,
    parameter DATA_SIZE_P      = DATA_WIDTH_P/8
 ) (
    input  wire                     clk_i,
    input  wire                     rst_i,

    // Vortex request
    input wire                      mem_req_vld [NUM_PORTS_IN_P],
    input wire                      mem_req_rw [NUM_PORTS_IN_P],
    input wire [DATA_SIZE_P-1:0]      mem_req_be [NUM_PORTS_IN_P],
    input wire [ADDR_WIDTH_IN_P-1:0]  mem_req_addr [NUM_PORTS_IN_P],
    input wire [DATA_WIDTH_P-1:0]     mem_req_data [NUM_PORTS_IN_P],
    input wire [TAG_WIDTH_IN_P-1:0]   mem_req_tag [NUM_PORTS_IN_P],
    output wire                     mem_req_rdy [NUM_PORTS_IN_P],

    // Vortex response
    output wire                     mem_resp_vld [NUM_PORTS_IN_P],
    output wire [DATA_WIDTH_P-1:0]    mem_resp_data [NUM_PORTS_IN_P],
    output wire [TAG_WIDTH_IN_P-1:0]  mem_resp_tag [NUM_PORTS_IN_P],
    input wire                      mem_resp_rdy [NUM_PORTS_IN_P],

    // AXI write request address channel
    output wire                     m_axi_awvld [NUM_BANKS_OUT_P],
    input wire                      m_axi_awrdy [NUM_BANKS_OUT_P],
    output wire [ADDR_WIDTH_OUT_P-1:0] m_axi_awaddr [NUM_BANKS_OUT_P],
    output wire [TAG_WIDTH_OUT_P-1:0] m_axi_awid [NUM_BANKS_OUT_P],
    output wire [7:0]               m_axi_awlen [NUM_BANKS_OUT_P],
    output wire [2:0]               m_axi_awsize [NUM_BANKS_OUT_P],
    output wire [1:0]               m_axi_awburst [NUM_BANKS_OUT_P],
    output wire [1:0]               m_axi_awlock [NUM_BANKS_OUT_P],
    output wire [3:0]               m_axi_awcache [NUM_BANKS_OUT_P],
    output wire [2:0]               m_axi_awprot [NUM_BANKS_OUT_P],
    output wire [3:0]               m_axi_awqos [NUM_BANKS_OUT_P],
    output wire [3:0]               m_axi_awregion [NUM_BANKS_OUT_P],

    // AXI write request data channel
    output wire                     m_axi_wvld [NUM_BANKS_OUT_P],
    input wire                      m_axi_wrdy [NUM_BANKS_OUT_P],
    output wire [DATA_WIDTH_P-1:0]    m_axi_wdata [NUM_BANKS_OUT_P],
    output wire [DATA_SIZE_P-1:0]     m_axi_wstrb [NUM_BANKS_OUT_P],
    output wire                     m_axi_wlast [NUM_BANKS_OUT_P],

    // AXI write response channel
    input wire                      m_axi_bvld [NUM_BANKS_OUT_P],
    output wire                     m_axi_brdy [NUM_BANKS_OUT_P],
    input wire [TAG_WIDTH_OUT_P-1:0]  m_axi_bid [NUM_BANKS_OUT_P],
    input wire [1:0]                m_axi_bresp [NUM_BANKS_OUT_P],

    // AXI read address channel
    output wire                     m_axi_arvld [NUM_BANKS_OUT_P],
    input wire                      m_axi_arrdy [NUM_BANKS_OUT_P],
    output wire [ADDR_WIDTH_OUT_P-1:0] m_axi_araddr [NUM_BANKS_OUT_P],
    output wire [TAG_WIDTH_OUT_P-1:0] m_axi_arid [NUM_BANKS_OUT_P],
    output wire [7:0]               m_axi_arlen [NUM_BANKS_OUT_P],
    output wire [2:0]               m_axi_arsize [NUM_BANKS_OUT_P],
    output wire [1:0]               m_axi_arburst [NUM_BANKS_OUT_P],
    output wire [1:0]               m_axi_arlock [NUM_BANKS_OUT_P],
    output wire [3:0]               m_axi_arcache [NUM_BANKS_OUT_P],
    output wire [2:0]               m_axi_arprot [NUM_BANKS_OUT_P],
    output wire [3:0]               m_axi_arqos [NUM_BANKS_OUT_P],
    output wire [3:0]               m_axi_arregion [NUM_BANKS_OUT_P],

    // AXI read response channel
    input wire                      m_axi_rvld [NUM_BANKS_OUT_P],
    output wire                     m_axi_rrdy [NUM_BANKS_OUT_P],
    input wire [DATA_WIDTH_P-1:0]     m_axi_rdata [NUM_BANKS_OUT_P],
    input wire                      m_axi_rlast [NUM_BANKS_OUT_P],
    input wire [TAG_WIDTH_OUT_P-1:0]  m_axi_rid [NUM_BANKS_OUT_P],
    input wire [1:0]                m_axi_rresp [NUM_BANKS_OUT_P]
);
    localparam LOG2_DATA_SIZE_P = `XM_CLOG2(DATA_SIZE_P);
    localparam BANK_SEL_BITS  = `XM_CLOG2(NUM_BANKS_OUT_P);
    localparam BANK_SEL_WIDTH = `XM_UP(BANK_SEL_BITS);
    localparam DST_ADDR_WDITH = (ADDR_WIDTH_OUT_P - LOG2_DATA_SIZE_P) + BANK_SEL_BITS; // convert output addresss to byte-addressable input space
    localparam BANK_ADDR_WIDTH = DST_ADDR_WDITH - BANK_SEL_BITS;
    localparam NUM_PORTS_IN_P_BITS = `XM_CLOG2(NUM_PORTS_IN_P);
    localparam NUM_PORTS_IN_P_WIDTH = `XM_UP(NUM_PORTS_IN_P_BITS);
    localparam TAG_BUFFER_ADDRW = `XM_CLOG2(TAG_BUFFER_SIZE_P);
    localparam NEEDED_TAG_WIDTH = TAG_WIDTH_IN_P + NUM_PORTS_IN_P_BITS;
    localparam READ_TAG_WIDTH = (NEEDED_TAG_WIDTH > TAG_WIDTH_OUT_P) ? TAG_BUFFER_ADDRW : TAG_WIDTH_IN_P;
    localparam READ_FULL_TAG_WIDTH = READ_TAG_WIDTH + NUM_PORTS_IN_P_BITS;
    localparam WRITE_TAG_WIDTH = `XM_MIN(TAG_WIDTH_IN_P, TAG_WIDTH_OUT_P);
    localparam DST_TAG_WIDTH  = `XM_MAX(READ_FULL_TAG_WIDTH, WRITE_TAG_WIDTH);
    localparam ARB_TAG_WIDTH  = `XM_MAX(READ_TAG_WIDTH, WRITE_TAG_WIDTH);
    localparam ARB_DATAW      = 1 + BANK_ADDR_WIDTH + DATA_SIZE_P + DATA_WIDTH_P + ARB_TAG_WIDTH;
    localparam RSP_XBAR_DATAW = DATA_WIDTH_P + READ_TAG_WIDTH;

    `STATIC_ASSERT ((DST_ADDR_WDITH >= ADDR_WIDTH_IN_P), ("invld address width: current=%0d, expected=%0d", DST_ADDR_WDITH, ADDR_WIDTH_IN_P))
    `STATIC_ASSERT ((TAG_WIDTH_OUT_P >= DST_TAG_WIDTH), ("invld output tag width: current=%0d, expected=%0d", TAG_WIDTH_OUT_P, DST_TAG_WIDTH))

    // Bank selection

    wire [NUM_PORTS_IN_P-1:0][BANK_SEL_WIDTH-1:0] req_bank_sel;
    wire [NUM_PORTS_IN_P-1:0][BANK_ADDR_WIDTH-1:0] req_bank_addr;

    if (NUM_BANKS_OUT_P > 1) begin : g_bank_sel
        for (genvar i = 0; i < NUM_PORTS_IN_P; ++i) begin : g_i
            wire [DST_ADDR_WDITH-1:0] mem_req_addr_dst = DST_ADDR_WDITH'(mem_req_addr[i]);
            if (INTERLEAVE_P) begin : g_interleave
                assign req_bank_sel[i]  = mem_req_addr_dst[BANK_SEL_BITS-1:0];
                assign req_bank_addr[i] = mem_req_addr_dst[BANK_SEL_BITS +: BANK_ADDR_WIDTH];
            end else begin : g_no_interleave
                assign req_bank_sel[i]  = mem_req_addr_dst[BANK_ADDR_WIDTH +: BANK_SEL_BITS];
                assign req_bank_addr[i] = mem_req_addr_dst[BANK_ADDR_WIDTH-1:0];
            end
        end
    end else begin : g_no_bank_sel
        for (genvar i = 0; i < NUM_PORTS_IN_P; ++i) begin : g_i
            assign req_bank_sel[i]  = '0;
            assign req_bank_addr[i] = DST_ADDR_WDITH'(mem_req_addr[i]);
        end
    end

    // Tag handling logic

    wire [NUM_PORTS_IN_P-1:0] mem_rd_req_tag_rdy;
    wire [NUM_PORTS_IN_P-1:0][READ_TAG_WIDTH-1:0] mem_rd_req_tag;
    wire [NUM_PORTS_IN_P-1:0][READ_TAG_WIDTH-1:0] mem_rd_resp_tag;

    for (genvar i = 0; i < NUM_PORTS_IN_P; ++i) begin : g_tag_buf
        if (NEEDED_TAG_WIDTH > TAG_WIDTH_OUT_P) begin : g_enabled
            wire [TAG_BUFFER_ADDRW-1:0] tbuf_waddr, tbuf_raddr;
            wire tbuf_full;
            xrv_index_buffer #(
                .DATA_WIDTH_P   (TAG_WIDTH_IN_P),
                .SIZE_P         (TAG_BUFFER_SIZE_P)
            ) tag_buf (
                .clk_i          (clk_i),
                .rst_i          (rst_i),
                .acquire_en     (mem_req_vld[i] && ~mem_req_rw[i] && mem_req_rdy[i]),
                .write_addr     (tbuf_waddr),
                .write_data     (mem_req_tag[i]),
                .read_data      (mem_resp_tag[i]),
                .read_addr      (tbuf_raddr),
                .release_en     (mem_resp_vld[i] && mem_resp_rdy[i]),
                .full           (tbuf_full),
                `XM_UNUSED_PIN     (empty)
            );
            assign mem_rd_req_tag_rdy[i] = ~tbuf_full;
            assign mem_rd_req_tag[i] = tbuf_waddr;
            assign tbuf_raddr = mem_rd_resp_tag[i];
        end else begin : g_none
            assign mem_rd_req_tag_rdy[i] = 1;
            assign mem_rd_req_tag[i] = mem_req_tag[i];
            assign mem_resp_tag[i] = mem_rd_resp_tag[i];
        end
    end

    // Request ack

    wire [NUM_BANKS_OUT_P-1:0][NUM_PORTS_IN_P-1:0] arb_rdy_in;

    if (NUM_PORTS_IN_P > 1) begin : g_multi_inputs
        wire [NUM_PORTS_IN_P-1:0][NUM_BANKS_OUT_P-1:0] arb_rdy_in_w;
        xrv_transpose #(
            .N_P          (NUM_BANKS_OUT_P),
            .M_P          (NUM_PORTS_IN_P)
        ) rdy_in_transpose (
            .data_i     (arb_rdy_in),
            .data_o     (arb_rdy_in_w)
        );
        for (genvar i = 0; i < NUM_PORTS_IN_P; ++i) begin : g_rdy_in
            assign mem_req_rdy[i] = | arb_rdy_in_w[i];
        end
    end else begin : g_single_input
        assign mem_req_rdy[0] = arb_rdy_in[req_bank_sel[0]][0];
    end

    // AXi write request synchronization

    wire [NUM_BANKS_OUT_P-1:0] m_axi_awvld_w, m_axi_wvld_w;
    wire [NUM_BANKS_OUT_P-1:0] m_axi_awrdy_w, m_axi_wrdy_w;
    reg [NUM_BANKS_OUT_P-1:0] m_axi_aw_ack, m_axi_w_ack, axi_write_rdy;

    for (genvar i = 0; i < NUM_BANKS_OUT_P; ++i) begin : g_axi_write_rdy
        xrv_axi_write_ack axi_write_ack (
            .clk_i      (clk_i),
            .rst_i      (rst_i),
            .awvld      (m_axi_awvld_w[i]),
            .awrdy      (m_axi_awrdy_w[i]),
            .wvld       (m_axi_wvld_w[i]),
            .wrdy       (m_axi_wrdy_w[i]),
            .aw_ack     (m_axi_aw_ack[i]),
            .w_ack      (m_axi_w_ack[i]),
            .tx_rdy     (axi_write_rdy[i]),
            `XM_UNUSED_PIN (tx_ack)
        );
    end

    // AXI request handling

    for (genvar i = 0; i < NUM_BANKS_OUT_P; ++i) begin : g_axi_write_req

        wire [BANK_ADDR_WIDTH-1:0] arb_addr_out, buf_addr_r_out, buf_addr_w_out;
        wire [ARB_TAG_WIDTH-1:0] arb_tag_out;
        wire [WRITE_TAG_WIDTH-1:0] buf_tag_w_out;
        wire [READ_FULL_TAG_WIDTH-1:0] arb_tag_r_out, buf_tag_r_out;
        wire [NUM_PORTS_IN_P_WIDTH-1:0] arb_sel_out;
        wire [DATA_WIDTH_P-1:0] arb_data_out;
        wire [DATA_SIZE_P-1:0] arb_be_out;
        wire arb_vld_out, arb_rdy_out;
        wire arb_rw_out;

        wire [NUM_PORTS_IN_P-1:0][ARB_DATAW-1:0] arb_data_in;
        wire [NUM_PORTS_IN_P-1:0] arb_vld_in;

        for (genvar j = 0; j < NUM_PORTS_IN_P; ++j) begin : g_vld_in
            wire tag_rdy = mem_req_rw[j] || mem_rd_req_tag_rdy[j];
            assign arb_vld_in[j] = mem_req_vld[j] && tag_rdy && (req_bank_sel[j] == i);
        end

        for (genvar j = 0; j < NUM_PORTS_IN_P; ++j) begin : g_data_in
            wire [ARB_TAG_WIDTH-1:0] tag_value = mem_req_rw[j] ? ARB_TAG_WIDTH'(mem_req_tag[j]) : ARB_TAG_WIDTH'(mem_rd_req_tag[j]);
            assign arb_data_in[j] = {mem_req_rw[j], req_bank_addr[j], mem_req_be[j], mem_req_data[j], tag_value};
        end

        xrv_stream_arb #(
            .NUM_INPUTS_P       (NUM_PORTS_IN_P),
            .NUM_OUTPUTS_P      (1),
            .DATA_WIDTH_P       (ARB_DATAW),
            .ARBITER_TYPE_P     (ARBITER_TYPE_P)
        ) aw_arb (
            .clk_i              (clk_i),
            .rst_i              (rst_i),
            .vld_i              (arb_vld_in),
            .rdy_i              (arb_rdy_in[i]),
            .data_i             (arb_data_in),
            .data_o             ({arb_rw_out, arb_addr_out, arb_be_out, arb_data_out, arb_tag_out}),
            .vld_o              (arb_vld_out),
            .rdy_o              (arb_rdy_out),
            .sel_o              (arb_sel_out)
        );

        wire m_axi_arrdy_w;

        assign arb_rdy_out = axi_write_rdy[i] || m_axi_arrdy_w;

        // AXI write address channel

        assign m_axi_awvld_w[i] = arb_vld_out && arb_rw_out && ~m_axi_aw_ack[i];

        xrv_elastic_buffer #(
            .DATA_WIDTH_P   (BANK_ADDR_WIDTH + WRITE_TAG_WIDTH),
            .SIZE_P         (`XM_TO_OUT_BUF_SIZE(REQ_OUT_BUF)),
            .OUT_REG        (`XM_TO_OUT_BUF_REG(REQ_OUT_BUF)),
            .LUTRAM         (`XM_TO_OUT_BUF_LUTRAM(REQ_OUT_BUF))
        ) aw_buf (
            .clk_i      (clk_i),
            .rst_i      (rst_i),
            .vld_i      (m_axi_awvld_w[i]),
            .rdy_i      (m_axi_awrdy_w[i]),
            .data_i     ({arb_addr_out, WRITE_TAG_WIDTH'(arb_tag_out)}),
            .data_o     ({buf_addr_w_out, buf_tag_w_out}),
            .vld_o      (m_axi_awvld[i]),
            .rdy_o      (m_axi_awrdy[i])
        );

        assign m_axi_awaddr[i]  = ADDR_WIDTH_OUT_P'(buf_addr_w_out) << LOG2_DATA_SIZE_P;
        assign m_axi_awid[i]    = TAG_WIDTH_OUT_P'(buf_tag_w_out);
        assign m_axi_awlen[i]   = 8'b00000000;
        assign m_axi_awsize[i]  = 3'(LOG2_DATA_SIZE_P);
        assign m_axi_awburst[i] = 2'b00;
        assign m_axi_awlock[i]  = 2'b00;
        assign m_axi_awcache[i] = 4'b0000;
        assign m_axi_awprot[i]  = 3'b000;
        assign m_axi_awqos[i]   = 4'b0000;
        assign m_axi_awregion[i]= 4'b0000;

        // AXI write data channel

        assign m_axi_wvld_w[i] = arb_vld_out && arb_rw_out && ~m_axi_w_ack[i];

        xrv_elastic_buffer #(
            .DATA_WIDTH_P   (DATA_SIZE_P + DATA_WIDTH_P),
            .SIZE_P         (`XM_TO_OUT_BUF_SIZE(REQ_OUT_BUF)),
            .OUT_REG        (`XM_TO_OUT_BUF_REG(REQ_OUT_BUF)),
            .LUTRAM         (`XM_TO_OUT_BUF_LUTRAM(REQ_OUT_BUF))
        ) w_buf (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .vld_i          (m_axi_wvld_w[i]),
            .rdy_i          (m_axi_wrdy_w[i]),
            .data_i         ({arb_be_out, arb_data_out}),
            .data_o         ({m_axi_wstrb[i], m_axi_wdata[i]}),
            .vld_o          (m_axi_wvld[i]),
            .rdy_o          (m_axi_wrdy[i])
        );

        assign m_axi_wlast[i] = 1'b1;

        // AXI read address channel

        if (NUM_PORTS_IN_P > 1) begin : g_input_sel
            assign arb_tag_r_out = READ_FULL_TAG_WIDTH'({arb_tag_out, arb_sel_out});
        end else begin : g_no_input_sel
            `XM_UNUSED_VAR (arb_sel_out)
            assign arb_tag_r_out = READ_TAG_WIDTH'(arb_tag_out);
        end

        xrv_elastic_buffer #(
            .DATA_WIDTH_P   (BANK_ADDR_WIDTH + READ_FULL_TAG_WIDTH),
            .SIZE_P         (`XM_TO_OUT_BUF_SIZE(REQ_OUT_BUF)),
            .OUT_REG        (`XM_TO_OUT_BUF_REG(REQ_OUT_BUF)),
            .LUTRAM         (`XM_TO_OUT_BUF_LUTRAM(REQ_OUT_BUF))
        ) ar_buf (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .vld_i          (arb_vld_out && ~arb_rw_out),
            .rdy_i          (m_axi_arrdy_w),
            .data_i         ({arb_addr_out,   arb_tag_r_out}),
            .data_o         ({buf_addr_r_out, buf_tag_r_out}),
            .vld_o          (m_axi_arvld[i]),
            .rdy_o          (m_axi_arrdy[i])
        );

        assign m_axi_araddr[i]  = ADDR_WIDTH_OUT_P'(buf_addr_r_out) << LOG2_DATA_SIZE_P;
        assign m_axi_arid[i]    = TAG_WIDTH_OUT_P'(buf_tag_r_out);
        assign m_axi_arlen[i]   = 8'b00000000;
        assign m_axi_arsize[i]  = 3'(LOG2_DATA_SIZE_P);
        assign m_axi_arburst[i] = 2'b00;
        assign m_axi_arlock[i]  = 2'b00;
        assign m_axi_arcache[i] = 4'b0000;
        assign m_axi_arprot[i]  = 3'b000;
        assign m_axi_arqos[i]   = 4'b0000;
        assign m_axi_arregion[i]= 4'b0000;
    end

    // AXI write response channel (ignore)

    for (genvar i = 0; i < NUM_BANKS_OUT_P; ++i) begin : g_axi_write_resp
        `XM_UNUSED_VAR (m_axi_bvld[i])
        `XM_UNUSED_VAR (m_axi_bid[i])
        `XM_UNUSED_VAR (m_axi_bresp[i])
        assign m_axi_brdy[i] = 1'b1;
        `RUNTIME_ASSERT(~m_axi_bvld[i] || m_axi_bresp[i] == 0, ("%t: *** AXI response error", $time))
    end

    // AXI read response channel

    wire [NUM_BANKS_OUT_P-1:0] resp_xbar_vld_in;
    wire [NUM_BANKS_OUT_P-1:0][RSP_XBAR_DATAW-1:0] resp_xbar_data_in;
    wire [NUM_BANKS_OUT_P-1:0][NUM_PORTS_IN_P_WIDTH-1:0] resp_xbar_sel_in;
    wire [NUM_BANKS_OUT_P-1:0] resp_xbar_rdy_in;

    for (genvar i = 0; i < NUM_BANKS_OUT_P; ++i) begin : g_resp_xbar_data_in
        assign resp_xbar_vld_in[i] = m_axi_rvld[i];
        assign resp_xbar_data_in[i] = {m_axi_rdata[i], m_axi_rid[i][NUM_PORTS_IN_P_BITS +: READ_TAG_WIDTH]};
        if (NUM_PORTS_IN_P > 1) begin : g_input_sel
            assign resp_xbar_sel_in[i] = m_axi_rid[i][0 +: NUM_PORTS_IN_P_BITS];
        end else begin : g_no_input_sel
            assign resp_xbar_sel_in[i] = 0;
        end
        assign m_axi_rrdy[i] = resp_xbar_rdy_in[i];
        `RUNTIME_ASSERT(~(m_axi_rvld[i] && m_axi_rlast[i] == 0), ("%t: *** AXI response error", $time))
        `RUNTIME_ASSERT(~(m_axi_rvld[i] && m_axi_rresp[i] != 0), ("%t: *** AXI response error", $time))
    end

    wire [NUM_PORTS_IN_P-1:0] resp_xbar_vld_out;
    wire [NUM_PORTS_IN_P-1:0][DATA_WIDTH_P+READ_TAG_WIDTH-1:0] resp_xbar_data_out;
    wire [NUM_PORTS_IN_P-1:0] resp_xbar_rdy_out;

    xrv_stream_xbar #(
        .NUM_INPUTS_P       (NUM_BANKS_OUT_P),
        .NUM_OUTPUTS_P      (NUM_PORTS_IN_P),
        .DATA_WIDTH_P       (RSP_XBAR_DATAW),
        .ARBITER_TYPE_P     (ARBITER_TYPE_P),
        .OUT_BUF            (RSP_OUT_BUF)
    ) resp_xbar (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .vld_i          (resp_xbar_vld_in),
        .data_i         (resp_xbar_data_in),
        .rdy_i          (resp_xbar_rdy_in),
        .sel_i          (resp_xbar_sel_in),
        .data_o         (resp_xbar_data_out),
        .vld_o          (resp_xbar_vld_out),
        .rdy_o          (resp_xbar_rdy_out),
        `XM_UNUSED_PIN  (collisions_o),
        `XM_UNUSED_PIN  (sel_o)
    );

    for (genvar i = 0; i < NUM_PORTS_IN_P; ++i) begin : g_resp_xbar_data_out
        assign mem_resp_vld[i] = resp_xbar_vld_out[i];
        assign {mem_resp_data[i], mem_rd_resp_tag[i]} = resp_xbar_data_out[i];
        assign resp_xbar_rdy_out[i] = mem_resp_rdy[i];
    end

endmodule
`TRACING_ON
