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

module xrv_vx_lsu_adapter import amoeba_gpu_pkg::*; #(
    parameter MEM_ADDR_WIDTH_P  = "inv",
    parameter NUM_LANES         = 1,
    parameter DATA_SIZE         = 1,
    parameter TAG_WIDTH         = 1,
    parameter TAG_SEL_BITS      = 0,
    parameter `STRING ARBITER   = "P",
    parameter REQ_OUT_BUF       = 0,
    parameter RSP_OUT_BUF       = 0
) (
    input wire              clk_i,
    input wire              rst_i,

    xrv_vx_lsu_mem_if.slave     lsu_mem_if,
    xrv_cache_if.master         mem_bus_if [NUM_LANES]
);
    localparam REQ_ADDR_WIDTH = MEM_ADDR_WIDTH_P - `XM_CLOG2(DATA_SIZE);
    localparam REQ_DATA_WIDTH = 1 + DATA_SIZE + REQ_ADDR_WIDTH + VX_MEM_REQ_FLAGS_WIDTH + DATA_SIZE * 8;
    localparam RSP_DATA_WIDTH = DATA_SIZE * 8;

    // handle request unpacking

    wire [NUM_LANES-1:0][REQ_DATA_WIDTH-1:0] req_data_in;

    wire [NUM_LANES-1:0] req_vld_out;
    wire [NUM_LANES-1:0][REQ_DATA_WIDTH-1:0] req_data_out;
    wire [NUM_LANES-1:0][TAG_WIDTH-1:0] req_tag_out;
    wire [NUM_LANES-1:0] req_rdy_out;

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_req_data_in
        assign req_data_in[i] = {
            lsu_mem_if.req_data.rw,
            lsu_mem_if.req_data.addr[i],
            lsu_mem_if.req_data.data[i],
            lsu_mem_if.req_data.be[i],
            lsu_mem_if.req_data.flags[i]
        };
    end

    xrv_stream_unpack #(
        .NUM_REQS_P (NUM_LANES),
        .DATA_WIDTH (REQ_DATA_WIDTH),
        .TAG_WIDTH  (TAG_WIDTH),
        .OUT_BUF    (REQ_OUT_BUF)
    ) stream_unpack (
        .clk_i        (clk_i),
        .rst_i      (rst_i),
        .vld_in   (lsu_mem_if.req_vld),
        .mask_in    (lsu_mem_if.req_data.mask),
        .data_in    (req_data_in),
        .tag_in     (lsu_mem_if.req_data.tag),
        .rdy_in   (lsu_mem_if.req_rdy),
        .vld_out  (req_vld_out),
        .data_out   (req_data_out),
        .tag_out    (req_tag_out),
        .rdy_out  (req_rdy_out)
    );

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_mem_bus_req
        assign mem_bus_if[i].req_vld = req_vld_out[i];
        assign {
            mem_bus_if[i].req_data.rw,
            mem_bus_if[i].req_data.addr,
            mem_bus_if[i].req_data.data,
            mem_bus_if[i].req_data.be,
            mem_bus_if[i].req_data.flags
         } = req_data_out[i];
        assign mem_bus_if[i].req_data.tag = req_tag_out[i];
        assign req_rdy_out[i] = mem_bus_if[i].req_rdy;
    end

    // handle response packing

    wire [NUM_LANES-1:0] resp_vld_out;
    wire [NUM_LANES-1:0][RSP_DATA_WIDTH-1:0] resp_data_out;
    wire [NUM_LANES-1:0][TAG_WIDTH-1:0] resp_tag_out;
    wire [NUM_LANES-1:0] resp_rdy_out;

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_mem_bus_resp
        assign resp_vld_out[i] = mem_bus_if[i].resp_vld;
        assign resp_data_out[i]  = mem_bus_if[i].resp_data.data;
        assign resp_tag_out[i]   = mem_bus_if[i].resp_data.tag;
        assign mem_bus_if[i].resp_rdy = resp_rdy_out[i];
    end

    xrv_stream_pack #(
        .NUM_REQS_P   (NUM_LANES),
        .DATA_WIDTH   (RSP_DATA_WIDTH),
        .TAG_WIDTH    (TAG_WIDTH),
        .TAG_SEL_BITS (TAG_SEL_BITS),
        .ARBITER      (ARBITER),
        .OUT_BUF      (RSP_OUT_BUF)
    ) stream_pack (
        .clk_i        (clk_i),
        .rst_i      (rst_i),
        .vld_in   (resp_vld_out),
        .data_in    (resp_data_out),
        .tag_in     (resp_tag_out),
        .rdy_in   (resp_rdy_out),
        .vld_out  (lsu_mem_if.resp_vld),
        .mask_out   (lsu_mem_if.resp_data.mask),
        .data_out   (lsu_mem_if.resp_data.data),
        .tag_out    (lsu_mem_if.resp_data.tag),
        .rdy_out  (lsu_mem_if.resp_rdy)
    );

endmodule
