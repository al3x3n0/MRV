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
`include "subsystems/vortex_cache/defines.svh"


module xrv_mem_switch #(
    parameter NUM_INPUTS_P      = 1,
    parameter NUM_OUTPUTS_P     = 1,
    parameter DATA_SIZE_P       = 1,
    parameter MEM_ADDR_WIDTH_P  = 32,
    parameter ADDR_WIDTH_P      = (MEM_ADDR_WIDTH_P-`XM_CLOG2(DATA_SIZE_P)),
    parameter TAG_WIDTH_P       = 1,
    parameter REQ_OUT_BUF       = 0,
    parameter RSP_OUT_BUF       = 0,
    parameter `STRING ARBITER_TYPE_P   = "R",
    parameter NUM_REQS          = (NUM_INPUTS_P > NUM_OUTPUTS_P) ? `XM_CDIV(NUM_INPUTS_P, NUM_OUTPUTS_P) : `XM_CDIV(NUM_OUTPUTS_P, NUM_INPUTS_P),
    parameter SEL_COUNT         = `XM_MIN(NUM_INPUTS_P, NUM_OUTPUTS_P),
    parameter LOG_NUM_REQS      = `XM_CLOG2(NUM_REQS)
) (
    input wire              clk_i,
    input wire              rst_i,

    input wire  [SEL_COUNT-1:0][`XM_UP(LOG_NUM_REQS)-1:0] bus_sel,
    xrv_cache_if.slave     bus_in_if [NUM_INPUTS_P],
    xrv_cache_if.master    bus_out_if [NUM_OUTPUTS_P]
);
    localparam DATA_WIDTH = (8 * DATA_SIZE_P);
    localparam REQ_DATA_WIDTH_P  = TAG_WIDTH_P + ADDR_WIDTH_P + `MEM_REQ_FLAGS_WIDTH + 1 + DATA_SIZE_P + DATA_WIDTH;
    localparam RSP_DATA_WIDTH_P  = TAG_WIDTH_P + DATA_WIDTH;

    // handle requests ////////////////////////////////////////////////////////

    wire [NUM_INPUTS_P-1:0]                 req_vld_in;
    wire [NUM_INPUTS_P-1:0][REQ_DATA_WIDTH_P-1:0]  req_data_in;
    wire [NUM_INPUTS_P-1:0]                 req_rdy_in;

    wire [NUM_OUTPUTS_P-1:0]                req_vld_out;
    wire [NUM_OUTPUTS_P-1:0][REQ_DATA_WIDTH_P-1:0] req_data_out;
    wire [NUM_OUTPUTS_P-1:0]                req_rdy_out;

    for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_req_data_in
        assign req_vld_in[i] = bus_in_if[i].req_vld;
        assign req_data_in[i]  = bus_in_if[i].req_data;
        assign bus_in_if[i].req_rdy = req_rdy_in[i];
    end

    xrv_stream_switch #(
        .NUM_INPUTS_P   (NUM_INPUTS_P),
        .NUM_OUTPUTS_P  (NUM_OUTPUTS_P),
        .DATA_WIDTH_P   (REQ_DATA_WIDTH_P),
        .OUT_BUF        (REQ_OUT_BUF)
    ) req_switch (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .sel_i      (bus_sel),
        .vld_i      (req_vld_in),
        .data_i     (req_data_in),
        .rdy_i      (req_rdy_in),
        .vld_o      (req_vld_out),
        .data_o     (req_data_out),
        .rdy_o      (req_rdy_out)
    );

    for (genvar i = 0; i < NUM_OUTPUTS_P; ++i) begin : g_req_data_out
        assign bus_out_if[i].req_vld = req_vld_out[i];
        assign bus_out_if[i].req_data  = req_data_out[i];
        assign req_rdy_out[i] = bus_out_if[i].req_rdy;
    end

    // handle responses ///////////////////////////////////////////////////////

    wire [NUM_OUTPUTS_P-1:0]              resp_vld_in;
    wire [NUM_OUTPUTS_P-1:0][RSP_DATA_WIDTH_P-1:0] resp_data_in;
    wire [NUM_OUTPUTS_P-1:0]              resp_rdy_in;

    wire [NUM_INPUTS_P-1:0]               resp_vld_out;
    wire [NUM_INPUTS_P-1:0][RSP_DATA_WIDTH_P-1:0] resp_data_out;
    wire [NUM_INPUTS_P-1:0]               resp_rdy_out;

    for (genvar i = 0; i < NUM_OUTPUTS_P; ++i) begin : g_resp_data_in
        assign resp_vld_in[i] = bus_out_if[i].resp_vld;
        assign resp_data_in[i]  = bus_out_if[i].resp_data;
        assign bus_out_if[i].resp_rdy = resp_rdy_in[i];
    end

    xrv_stream_arb #(
        .NUM_INPUTS_P   (NUM_OUTPUTS_P),
        .NUM_OUTPUTS_P  (NUM_INPUTS_P),
        .DATA_WIDTH_P   (RSP_DATA_WIDTH_P),
        .ARBITER_TYPE_P        (ARBITER_TYPE_P),
        .OUT_BUF        (RSP_OUT_BUF)
    ) resp_arb (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .vld_i      (resp_vld_in),
        .data_i     (resp_data_in),
        .rdy_i      (resp_rdy_in),
        .vld_o      (resp_vld_out),
        .data_o     (resp_data_out),
        .rdy_o      (resp_rdy_out),
        `XM_UNUSED_PIN (sel_o)
    );

    for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_resp_data_out
        assign bus_in_if[i].resp_vld = resp_vld_out[i];
        assign bus_in_if[i].resp_data  = resp_data_out[i];
        assign resp_rdy_out[i] = bus_in_if[i].resp_rdy;
    end

endmodule
