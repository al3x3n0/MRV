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

`include "subsystems/vortex_cache/defines.svh"
`include "xm_macro.svh"


module xrv_mem_arb #(
    parameter NUM_INPUTS_P      = 1,
    parameter NUM_OUTPUTS_P     = 1,
    parameter DATA_SIZE_P       = 1,
    parameter TAG_WIDTH_P       = 1,
    parameter TAG_SEL_IDX       = 0,
    parameter REQ_OUT_BUF       = 0,
    parameter RSP_OUT_BUF       = 0,
    parameter `STRING ARBITER_TYPE_P = "R",
    parameter MEM_ADDR_WIDTH    = 32, // 'MEM_ADDR_WIDTH
    parameter ADDR_WIDTH        = (MEM_ADDR_WIDTH-`XM_CLOG2(DATA_SIZE_P)),
    parameter FLAGS_WIDTH       = `MEM_REQ_FLAGS_WIDTH
) (
    input wire              clk_i,
    input wire              rst_i,

    xrv_cache_if.slave     bus_in_if [NUM_INPUTS_P],
    xrv_cache_if.master    bus_out_if [NUM_OUTPUTS_P]
);
    localparam DATA_WIDTH   = (8 * DATA_SIZE_P);
    localparam LOG_NUM_REQS = `XM_ARB_SEL_BITS(NUM_INPUTS_P, NUM_OUTPUTS_P);
    localparam REQ_DATA_WIDTH_LP    = 1 + ADDR_WIDTH + DATA_WIDTH + DATA_SIZE_P + FLAGS_WIDTH + TAG_WIDTH_P;
    localparam RESP_DATA_WIDTH_LP    = DATA_WIDTH + TAG_WIDTH_P;

    `STATIC_ASSERT ((NUM_INPUTS_P >= NUM_OUTPUTS_P), ("invalid parameter: NUM_INPUTS_P=%0d, NUM_OUTPUTS_P=%0d", NUM_INPUTS_P, NUM_OUTPUTS_P));

    wire [NUM_INPUTS_P-1:0]                 req_vld_i;
    wire [NUM_INPUTS_P-1:0][REQ_DATA_WIDTH_LP-1:0]  req_data_i;
    wire [NUM_INPUTS_P-1:0]                 req_rdy_i;

    wire [NUM_OUTPUTS_P-1:0]                req_vld_o;
    wire [NUM_OUTPUTS_P-1:0][REQ_DATA_WIDTH_LP-1:0] req_data_o;
    wire [NUM_OUTPUTS_P-1:0][`XM_UP(LOG_NUM_REQS)-1:0] req_sel_o;
    wire [NUM_OUTPUTS_P-1:0]                req_rdy_o;

    for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_req_data_i
        assign req_vld_i[i] = bus_in_if[i].req_vld;
        assign req_data_i[i]  = bus_in_if[i].req_data;
        assign bus_in_if[i].req_rdy = req_rdy_i[i];
    end

    xrv_stream_arb #(
        .NUM_INPUTS_P   (NUM_INPUTS_P),
        .NUM_OUTPUTS_P  (NUM_OUTPUTS_P),
        .DATA_WIDTH_P   (REQ_DATA_WIDTH_LP),
        .ARBITER_TYPE_P (ARBITER_TYPE_P),
        .OUT_BUF        (REQ_OUT_BUF)
    ) req_arb (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .vld_i       (req_vld_i),
        .rdy_i       (req_rdy_i),
        .data_i        (req_data_i),
        .data_o       (req_data_o),
        .sel_o        (req_sel_o),
        .vld_o      (req_vld_o),
        .rdy_o      (req_rdy_o)
    );

    for (genvar i = 0; i < NUM_OUTPUTS_P; ++i) begin : g_bus_out_if
        wire [TAG_WIDTH_P-1:0] req_tag_out;
        xrv_bits_insert #(
            .N          (TAG_WIDTH_P),
            .S          (LOG_NUM_REQS),
            .POS        (TAG_SEL_IDX)
        ) bits_insert (
            .data_i     (req_tag_out),
            .ins_i      (req_sel_o[i]),
            .data_o     (bus_out_if[i].req_data.tag)
        );
        assign bus_out_if[i].req_vld = req_vld_o[i];
        assign {
            bus_out_if[i].req_data.rw,
            bus_out_if[i].req_data.addr,
            bus_out_if[i].req_data.data,
            bus_out_if[i].req_data.be,
            bus_out_if[i].req_data.flags,
            req_tag_out
        } = req_data_o[i];
        assign req_rdy_o[i] = bus_out_if[i].req_rdy;
    end

    ///////////////////////////////////////////////////////////////////////////

    wire [NUM_INPUTS_P-1:0]                 resp_vld_o;
    wire [NUM_INPUTS_P-1:0][RESP_DATA_WIDTH_LP-1:0]  resp_data_o;
    wire [NUM_INPUTS_P-1:0]                 resp_rdy_o;

    wire [NUM_OUTPUTS_P-1:0]                resp_vld_i;
    wire [NUM_OUTPUTS_P-1:0][RESP_DATA_WIDTH_LP-1:0] resp_data_i;
    wire [NUM_OUTPUTS_P-1:0]                resp_rdy_i;

    if (NUM_INPUTS_P > NUM_OUTPUTS_P) begin : g_resp_enabled

        wire [NUM_OUTPUTS_P-1:0][LOG_NUM_REQS-1:0] resp_sel_i;

        for (genvar i = 0; i < NUM_OUTPUTS_P; ++i) begin : g_resp_data_i
            wire [TAG_WIDTH_P-1:0] resp_tag_out;
            xrv_bits_remove #(
                .N   (TAG_WIDTH_P + LOG_NUM_REQS),
                .S   (LOG_NUM_REQS),
                .POS (TAG_SEL_IDX)
            ) bits_remove (
                .data_i  (bus_out_if[i].resp_data.tag),
                .sel_o  (resp_sel_i[i]),
                .data_o (resp_tag_out)
            );
            assign resp_vld_i[i] = bus_out_if[i].resp_vld;
            assign resp_data_i[i]  = {bus_out_if[i].resp_data.data, resp_tag_out};
            assign bus_out_if[i].resp_rdy = resp_rdy_i[i];
        end

        xrv_stream_switch #(
            .NUM_INPUTS_P   (NUM_OUTPUTS_P),
            .NUM_OUTPUTS_P  (NUM_INPUTS_P),
            .DATA_WIDTH_P   (RESP_DATA_WIDTH_LP),
            .OUT_BUF        (RSP_OUT_BUF)
        ) resp_switch (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .sel_i          (resp_sel_i),
            .vld_i          (resp_vld_i),
            .rdy_i          (resp_rdy_i),
            .data_i         (resp_data_i),
            .data_o       (resp_data_o),
            .vld_o        (resp_vld_o),
            .rdy_o        (resp_rdy_o)
        );

    end else begin : g_passthru

        for (genvar i = 0; i < NUM_OUTPUTS_P; ++i) begin : g_resp_data_i
            assign resp_vld_i[i] = bus_out_if[i].resp_vld;
            assign resp_data_i[i]  = bus_out_if[i].resp_data;
            assign bus_out_if[i].resp_rdy = resp_rdy_i[i];
        end

        xrv_stream_arb #(
            .NUM_INPUTS_P       (NUM_OUTPUTS_P),
            .NUM_OUTPUTS_P      (NUM_INPUTS_P),
            .DATA_WIDTH_P       (RESP_DATA_WIDTH_LP),
            .ARBITER_TYPE_P     (ARBITER_TYPE_P),
            .OUT_BUF            (RSP_OUT_BUF)
        ) req_arb (
            .clk_i              (clk_i),
            .rst_i              (rst_i),
            .vld_i              (resp_vld_i),
            .rdy_i              (resp_rdy_i),
            .data_i             (resp_data_i),
            .data_o             (resp_data_o),
            .vld_o              (resp_vld_o),
            .rdy_o              (resp_rdy_o),
            `XM_UNUSED_PIN      (sel_o)
        );

    end

    for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_output
        assign bus_in_if[i].resp_vld = resp_vld_o[i];
        assign bus_in_if[i].resp_data  = resp_data_o[i];
        assign resp_rdy_o[i] = bus_in_if[i].resp_rdy;
    end

endmodule
