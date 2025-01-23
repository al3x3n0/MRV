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


module xrv_cache_bypass #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                    = 32,
    parameter MEM_ADDR_WIDTH_P          = (XLEN_P == 32 ? 32 : 48),
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_REQS_P                = 1,
    parameter NUM_MEM_PORTS_P           = 1,
    parameter TAG_SEL_IDX               = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter CACHE_ENABLED_P           = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter WORD_SIZE_P               = 1,
    parameter LINE_SIZE_P               = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter CORE_ADDR_WIDTH_P         = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter CORE_TAG_WIDTH_P          = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter CACHE_MEM_ADDR_WIDTH_P     = 1,
    parameter CACHE_MEM_TAG_IN_WIDTH_P   = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P              = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter CORE_OUT_BUF              = 0,
    parameter MEM_OUT_BUF               = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter CACHE_WORDS_PER_LINE_LP = (LINE_SIZE_P / WORD_SIZE_P),
    parameter CACHE_WORD_SEL_BITS_LP = `XM_CLOG2(CACHE_WORDS_PER_LINE_LP)
 ) (
    input wire clk_i,
    input wire rst_i,

    // Core request in
    xrv_cache_if.slave     core_bus_in_if [NUM_REQS_P],

    // Core request out
    xrv_cache_if.master    core_bus_out_if [NUM_REQS_P],

    // Memory request in
    xrv_cache_if.slave     mem_bus_in_if [NUM_MEM_PORTS_P],

    // Memory request out
    xrv_cache_if.master    mem_bus_out_if [NUM_MEM_PORTS_P]
);
    localparam DIRECT_PASSTHRU      = !CACHE_ENABLED_P && (CACHE_WORD_SEL_BITS_LP == 0) && (NUM_REQS_P == NUM_MEM_PORTS_P);
    localparam CORE_DATA_WIDTH      = WORD_SIZE_P * 8;
    localparam WORDS_PER_LINE_LP    = LINE_SIZE_P / WORD_SIZE_P;
    localparam WSEL_BITS            = `XM_CLOG2(WORDS_PER_LINE_LP);

    localparam CORE_TAG_ID_WIDTH = CORE_TAG_WIDTH_P - UUID_WIDTH_P;
    localparam MEM_TAG_ID_WIDTH  = `XM_CLOG2(`XM_CDIV(NUM_REQS_P, NUM_MEM_PORTS_P)) + CORE_TAG_ID_WIDTH;
    localparam MEM_TAG_NC1_WIDTH = UUID_WIDTH_P + MEM_TAG_ID_WIDTH;
    localparam MEM_TAG_NC2_WIDTH = MEM_TAG_NC1_WIDTH + WSEL_BITS;
    localparam MEM_TAG_OUT_WIDTH = CACHE_ENABLED_P ? `XM_MAX(CACHE_MEM_TAG_IN_WIDTH_P, MEM_TAG_NC2_WIDTH) : MEM_TAG_NC2_WIDTH;

    //`STATIC_ASSERT(0 == (`IO_BASE_ADDR % `MEM_BLOCK_SIZE), ("invalid parameter"))

    // hanlde non-cacheable core request switch ///////////////////////////////

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (WORD_SIZE_P),
        .TAG_WIDTH_P        (CORE_TAG_WIDTH_P)
    ) core_bus_nc_switch_if[(CACHE_ENABLED_P ? 2 : 1) * NUM_REQS_P]();

    wire [NUM_REQS_P-1:0] core_req_nc_sel;

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_req_is_nc
        if (CACHE_ENABLED_P) begin : g_cache
            assign core_req_nc_sel[i] = ~core_bus_in_if[i].req_data.flags[`MEM_REQ_FLAG_IO];
        end else begin : g_no_cache
            assign core_req_nc_sel[i] = 1'b0;
        end
    end

    xrv_mem_switch #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .NUM_INPUTS_P       (NUM_REQS_P),
        .NUM_OUTPUTS_P      ((CACHE_ENABLED_P ? 2 : 1) * NUM_REQS_P),
        .DATA_SIZE_P        (WORD_SIZE_P),
        .TAG_WIDTH_P        (CORE_TAG_WIDTH_P),
        .ARBITER_TYPE_P     ("R"),
        .REQ_OUT_BUF        (0),
        .RSP_OUT_BUF        (DIRECT_PASSTHRU ? 0 : `XM_TO_OUT_BUF_SIZE(CORE_OUT_BUF))
    ) core_bus_nc_switch (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .bus_sel        (core_req_nc_sel),
        .bus_in_if      (core_bus_in_if),
        .bus_out_if     (core_bus_nc_switch_if)
    );

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (WORD_SIZE_P),
        .TAG_WIDTH_P        (CORE_TAG_WIDTH_P)
    ) core_bus_in_nc_if[NUM_REQS_P]();

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_bus_nc_switch_if

        assign core_bus_in_nc_if[i].req_vld = core_bus_nc_switch_if[0 * NUM_REQS_P + i].req_vld;
        assign core_bus_in_nc_if[i].req_data  = core_bus_nc_switch_if[0 * NUM_REQS_P + i].req_data;
        assign core_bus_nc_switch_if[0 * NUM_REQS_P + i].req_rdy = core_bus_in_nc_if[i].req_rdy;

        assign core_bus_nc_switch_if[0 * NUM_REQS_P + i].resp_vld = core_bus_in_nc_if[i].resp_vld;
        assign core_bus_nc_switch_if[0 * NUM_REQS_P + i].resp_data  = core_bus_in_nc_if[i].resp_data;
        assign core_bus_in_nc_if[i].resp_rdy = core_bus_nc_switch_if[0 * NUM_REQS_P + i].resp_rdy;

        if (CACHE_ENABLED_P) begin : g_cache
            assign core_bus_out_if[i].req_vld = core_bus_nc_switch_if[1 * NUM_REQS_P + i].req_vld;
            assign core_bus_out_if[i].req_data  = core_bus_nc_switch_if[1 * NUM_REQS_P + i].req_data;
            assign core_bus_nc_switch_if[1 * NUM_REQS_P + i].req_rdy = core_bus_out_if[i].req_rdy;

            assign core_bus_nc_switch_if[1 * NUM_REQS_P + i].resp_vld = core_bus_out_if[i].resp_vld;
            assign core_bus_nc_switch_if[1 * NUM_REQS_P + i].resp_data  = core_bus_out_if[i].resp_data;
            assign core_bus_out_if[i].resp_rdy = core_bus_nc_switch_if[1 * NUM_REQS_P + i].resp_rdy;
        end else begin : g_no_cache
            `INIT_XRV_CACHE_IF (core_bus_out_if[i])
        end
    end

    // handle memory requests /////////////////////////////////////////////////

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (WORD_SIZE_P),
        .TAG_WIDTH_P        (MEM_TAG_NC1_WIDTH)
    ) core_bus_nc_arb_if[NUM_MEM_PORTS_P]();

    xrv_mem_arb #(
        .NUM_INPUTS_P   (NUM_REQS_P),
        .NUM_OUTPUTS_P  (NUM_MEM_PORTS_P),
        .DATA_SIZE_P    (WORD_SIZE_P),
        .TAG_WIDTH_P    (CORE_TAG_WIDTH_P),
        .TAG_SEL_IDX    (TAG_SEL_IDX),
        .ARBITER_TYPE_P (CACHE_ENABLED_P ? "P" : "R"),
        .REQ_OUT_BUF    (0),
        .RSP_OUT_BUF    (0)
    ) core_bus_nc_arb (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .bus_in_if      (core_bus_in_nc_if),
        .bus_out_if     (core_bus_nc_arb_if)
    );

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (LINE_SIZE_P),
        .TAG_WIDTH_P        (MEM_TAG_NC2_WIDTH)
    ) mem_bus_out_nc_if[NUM_MEM_PORTS_P]();

    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_mem_bus_out_nc
        wire                        core_req_nc_arb_rw;
        wire [WORD_SIZE_P-1:0]        core_req_nc_arb_byteen;
        wire [CORE_ADDR_WIDTH_P-1:0]  core_req_nc_arb_addr;
        wire [`MEM_REQ_FLAGS_WIDTH-1:0] core_req_nc_arb_flags;
        wire [CORE_DATA_WIDTH-1:0]  core_req_nc_arb_data;
        wire [MEM_TAG_NC1_WIDTH-1:0] core_req_nc_arb_tag;

        assign {
            core_req_nc_arb_rw,
            core_req_nc_arb_addr,
            core_req_nc_arb_data,
            core_req_nc_arb_byteen,
            core_req_nc_arb_flags,
            core_req_nc_arb_tag
        } = core_bus_nc_arb_if[i].req_data;

        logic [CACHE_MEM_ADDR_WIDTH_P-1:0] core_req_nc_arb_addr_w;
        logic [WORDS_PER_LINE_LP-1:0][WORD_SIZE_P-1:0] core_req_nc_arb_byteen_w;
        logic [WORDS_PER_LINE_LP-1:0][CORE_DATA_WIDTH-1:0] core_req_nc_arb_data_w;
        logic [CORE_DATA_WIDTH-1:0] core_resp_nc_arb_data_w;
        wire [MEM_TAG_NC2_WIDTH-1:0] core_req_nc_arb_tag_w;
        wire [MEM_TAG_NC1_WIDTH-1:0] core_resp_nc_arb_tag_w;

        if (WORDS_PER_LINE_LP > 1) begin : g_multi_word_line
            wire [WSEL_BITS-1:0] resp_wsel;
            wire [WSEL_BITS-1:0] req_wsel = core_req_nc_arb_addr[WSEL_BITS-1:0];
            always_comb begin
                core_req_nc_arb_byteen_w = '0;
                core_req_nc_arb_byteen_w[req_wsel] = core_req_nc_arb_byteen;
                core_req_nc_arb_data_w = 'x;
                core_req_nc_arb_data_w[req_wsel] = core_req_nc_arb_data;
            end
            xrv_bits_insert #(
                .N   (MEM_TAG_NC1_WIDTH),
                .S   (WSEL_BITS),
                .POS (TAG_SEL_IDX)
            ) wsel_insert (
                .data_i     (core_req_nc_arb_tag),
                .ins_i      (req_wsel),
                .data_o     (core_req_nc_arb_tag_w)
            );
            xrv_bits_remove #(
                .N   (MEM_TAG_NC2_WIDTH),
                .S   (WSEL_BITS),
                .POS (TAG_SEL_IDX)
            ) wsel_remove (
                .data_i     (mem_bus_out_nc_if[i].resp_data.tag),
                .sel_o      (resp_wsel),
                .data_o     (core_resp_nc_arb_tag_w)
            );
            assign core_req_nc_arb_addr_w   = core_req_nc_arb_addr[WSEL_BITS +: CACHE_MEM_ADDR_WIDTH_P];
            assign core_resp_nc_arb_data_w   = mem_bus_out_nc_if[i].resp_data.data[resp_wsel * CORE_DATA_WIDTH +: CORE_DATA_WIDTH];
        end else begin : g_single_word_line
            assign core_req_nc_arb_addr_w   = core_req_nc_arb_addr;
            assign core_req_nc_arb_byteen_w = core_req_nc_arb_byteen;
            assign core_req_nc_arb_data_w   = core_req_nc_arb_data;
            assign core_req_nc_arb_tag_w    = MEM_TAG_NC2_WIDTH'(core_req_nc_arb_tag);

            assign core_resp_nc_arb_data_w   = mem_bus_out_nc_if[i].resp_data.data;
            assign core_resp_nc_arb_tag_w    = MEM_TAG_NC1_WIDTH'(mem_bus_out_nc_if[i].resp_data.tag);
        end

        assign mem_bus_out_nc_if[i].req_vld = core_bus_nc_arb_if[i].req_vld;
        assign mem_bus_out_nc_if[i].req_data = {
            core_req_nc_arb_rw,
            core_req_nc_arb_addr_w,
            core_req_nc_arb_data_w,
            core_req_nc_arb_byteen_w,
            core_req_nc_arb_flags,
            core_req_nc_arb_tag_w
        };
        assign core_bus_nc_arb_if[i].req_rdy = mem_bus_out_nc_if[i].req_rdy;

        assign core_bus_nc_arb_if[i].resp_vld = mem_bus_out_nc_if[i].resp_vld;
        assign core_bus_nc_arb_if[i].resp_data = {
            core_resp_nc_arb_data_w,
            core_resp_nc_arb_tag_w
        };
        assign mem_bus_out_nc_if[i].resp_rdy = core_bus_nc_arb_if[i].resp_rdy;
    end

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (LINE_SIZE_P),
        .TAG_WIDTH_P        (MEM_TAG_OUT_WIDTH)
    ) mem_bus_out_src_if[(CACHE_ENABLED_P ? 2 : 1) * NUM_MEM_PORTS_P]();

    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_mem_bus_out_src
        `ASSIGN_XRV_CACHE_IF_EX(mem_bus_out_src_if[0 * NUM_MEM_PORTS_P + i], mem_bus_out_nc_if[i], MEM_TAG_OUT_WIDTH, MEM_TAG_NC2_WIDTH, UUID_WIDTH_P);
        if (CACHE_ENABLED_P) begin : g_cache
            `ASSIGN_XRV_CACHE_IF_EX(mem_bus_out_src_if[1 * NUM_MEM_PORTS_P + i], mem_bus_in_if[i], MEM_TAG_OUT_WIDTH, CACHE_MEM_TAG_IN_WIDTH_P, UUID_WIDTH_P);
        end else begin : g_no_cache
            `UNUSED_XRV_CACHE_IF(mem_bus_in_if[i])
        end
    end

    xrv_mem_arb #(
        .NUM_INPUTS_P       ((CACHE_ENABLED_P ? 2 : 1) * NUM_MEM_PORTS_P),
        .NUM_OUTPUTS_P      (NUM_MEM_PORTS_P),
        .DATA_SIZE_P        (LINE_SIZE_P),
        .TAG_WIDTH_P        (MEM_TAG_OUT_WIDTH),
        .ARBITER_TYPE_P     ("R"),
        .REQ_OUT_BUF        (DIRECT_PASSTHRU ? 0 : `XM_TO_OUT_BUF_SIZE(MEM_OUT_BUF)),
        .RSP_OUT_BUF        (0)
    ) mem_bus_out_arb (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .bus_in_if          (mem_bus_out_src_if),
        .bus_out_if         (mem_bus_out_if)
    );

endmodule
