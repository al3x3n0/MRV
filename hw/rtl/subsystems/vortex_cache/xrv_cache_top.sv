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


module xrv_cache_top #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                    = 64,
    parameter MEM_ADDR_WIDTH_P          = XLEN_P,
    ////////////////////////////////////////////////////////////////////////////////
    parameter `STRING INSTANCE_ID       = "",
    ////////////////////////////////////////////////////////////////////////////////
    // Number of Word requests per cycle
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_REQS_P                = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Number of memory ports
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_MEM_PORTS_P           = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Size of cache in bytes
    ////////////////////////////////////////////////////////////////////////////////
    parameter CACHE_SIZE_P              = 65536,
    ////////////////////////////////////////////////////////////////////////////////
    // Size of line inside a bank in bytes
    ////////////////////////////////////////////////////////////////////////////////
    parameter LINE_SIZE_P               = 64,
    ////////////////////////////////////////////////////////////////////////////////
    // Number of banks
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_BANKS_P               = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Number of associative ways
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_WAYS_P                = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Size of a word in bytes
    ////////////////////////////////////////////////////////////////////////////////
    parameter WORD_SIZE_P               = 16,
    ////////////////////////////////////////////////////////////////////////////////
    // Core Response Queue Size
    ////////////////////////////////////////////////////////////////////////////////
    parameter CRSQ_SIZE_P               = 8,
    ////////////////////////////////////////////////////////////////////////////////
    // Miss Reserv Queue Knob
    ////////////////////////////////////////////////////////////////////////////////
    parameter MSHR_SIZE_P               = 16,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory Response Queue Size
    ////////////////////////////////////////////////////////////////////////////////
    parameter MRSQ_SIZE_P               = 8,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory Request Queue Size
    ////////////////////////////////////////////////////////////////////////////////
    parameter MREQ_SIZE_P               = 8,
    ////////////////////////////////////////////////////////////////////////////////
    // Enable cache writeable
    ////////////////////////////////////////////////////////////////////////////////
    parameter IS_WRITEABLE_P            = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Enable cache writeback
    ////////////////////////////////////////////////////////////////////////////////
    parameter HAS_WRITEBACK_P           = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Enable dirty bytes on writeback
    ////////////////////////////////////////////////////////////////////////////////
    parameter HAS_DIRTY_BYTES_P         = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Request debug identifier
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P                = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // core request tag size
    ////////////////////////////////////////////////////////////////////////////////
    parameter TAG_WIDTH_P               = 32,
    ////////////////////////////////////////////////////////////////////////////////
    // Core response output buffer
    ////////////////////////////////////////////////////////////////////////////////
    parameter CORE_OUT_BUF              = 3,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory request output buffer
    ////////////////////////////////////////////////////////////////////////////////
    parameter MEM_OUT_BUF               = 3,
    parameter MEM_TAG_WIDTH_LP          = `CACHE_MEM_TAG_WIDTH(MSHR_SIZE_P, NUM_BANKS_P, NUM_MEM_PORTS_P, UUID_WIDTH_P),
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CACHE_LOCALPARAMS
    ////////////////////////////////////////////////////////////////////////////////
 ) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 clk_i,
    input logic                                 rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // PERF
    ////////////////////////////////////////////////////////////////////////////////
`ifdef PERF_ENABLE
    output cache_perf_t                         cache_perf,
`endif
    ////////////////////////////////////////////////////////////////////////////////
    // Core request
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                core_req_vld [NUM_REQS_P],
    input  logic                                core_req_rw [NUM_REQS_P],
    input  logic [WORD_SIZE_P-1:0]              core_req_be [NUM_REQS_P],
    input  logic [CACHE_WORD_ADDR_WIDTH_LP-1:0] core_req_addr [NUM_REQS_P],
    input  logic [`MEM_REQ_FLAGS_WIDTH-1:0]     core_req_flags [NUM_REQS_P],
    input  logic [CACHE_WORD_WIDTH_LP-1:0]      core_req_data [NUM_REQS_P],
    input  logic [TAG_WIDTH_P-1:0]              core_req_tag [NUM_REQS_P],
    output logic                                core_req_rdy [NUM_REQS_P],
    ////////////////////////////////////////////////////////////////////////////////
    // Core response
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                core_resp_vld [NUM_REQS_P],
    output logic [CACHE_WORD_WIDTH_LP-1:0]      core_resp_data [NUM_REQS_P],
    output logic [TAG_WIDTH_P-1:0]              core_resp_tag [NUM_REQS_P],
    input  logic                                core_resp_rdy [NUM_REQS_P],
    ////////////////////////////////////////////////////////////////////////////////
    // Memory request
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                mem_req_vld [NUM_MEM_PORTS_P],
    output logic                                mem_req_rw [NUM_MEM_PORTS_P],
    output logic [LINE_SIZE_P-1:0]              mem_req_be [NUM_MEM_PORTS_P],
    output logic [CACHE_MEM_ADDR_WIDTH_LP-1:0]  mem_req_addr [NUM_MEM_PORTS_P],
    output logic [CACHE_LINE_WIDTH_LP-1:0]      mem_req_data [NUM_MEM_PORTS_P],
    output logic [MEM_TAG_WIDTH_LP-1:0]         mem_req_tag [NUM_MEM_PORTS_P],
    input  logic                                mem_req_rdy [NUM_MEM_PORTS_P],
    ////////////////////////////////////////////////////////////////////////////////
    // Memory response
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                mem_resp_vld [NUM_MEM_PORTS_P],
    input  logic [CACHE_LINE_WIDTH_LP-1:0]      mem_resp_data [NUM_MEM_PORTS_P],
    input  logic [MEM_TAG_WIDTH_LP-1:0]         mem_resp_tag [NUM_MEM_PORTS_P],
    output logic                                mem_resp_rdy [NUM_MEM_PORTS_P]
);
    xrv_cache_if #(
        .DATA_SIZE_P        (WORD_SIZE_P),
        .TAG_WIDTH_P        (TAG_WIDTH_P)
    ) core_bus_if[NUM_REQS_P]();

    xrv_cache_if #(
        .DATA_SIZE_P        (LINE_SIZE_P),
        .TAG_WIDTH_P        (MEM_TAG_WIDTH_LP)
    ) mem_bus_if[NUM_MEM_PORTS_P]();

    ////////////////////////////////////////////////////////////////////////////////
    // Core request
    ////////////////////////////////////////////////////////////////////////////////
    for (genvar i = 0; i < NUM_REQS_P; ++i) begin
        assign core_bus_if[i].req_vld = core_req_vld[i];
        assign core_bus_if[i].req_data.rw = core_req_rw[i];
        assign core_bus_if[i].req_data.be = core_req_be[i];
        assign core_bus_if[i].req_data.addr = core_req_addr[i];
        assign core_bus_if[i].req_data.flags = core_req_flags[i];
        assign core_bus_if[i].req_data.data = core_req_data[i];
        assign core_bus_if[i].req_data.tag = core_req_tag[i];
        assign core_req_rdy[i] = core_bus_if[i].req_rdy;
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Core response
    ////////////////////////////////////////////////////////////////////////////////
    for (genvar i = 0; i < NUM_REQS_P; ++i) begin
        assign core_resp_vld[i] = core_bus_if[i].resp_vld;
        assign core_resp_data[i] = core_bus_if[i].resp_data.data;
        assign core_resp_tag[i] = core_bus_if[i].resp_data.tag;
        assign core_bus_if[i].resp_rdy = core_resp_rdy[i];
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Memory request
    ////////////////////////////////////////////////////////////////////////////////
    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin
        assign mem_req_vld[i] = mem_bus_if[i].req_vld;
        assign mem_req_rw[i] = mem_bus_if[i].req_data.rw;
        assign mem_req_be[i]= mem_bus_if[i].req_data.be;
        assign mem_req_addr[i] = mem_bus_if[i].req_data.addr;
        assign mem_req_data[i] = mem_bus_if[i].req_data.data;
        assign mem_req_tag[i] = mem_bus_if[i].req_data.tag;
        assign mem_bus_if[i].req_rdy = mem_req_rdy[i];
    end

    ////////////////////////////////////////////////////////////////////////////////
    // Memory response
    ////////////////////////////////////////////////////////////////////////////////
    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin
        assign mem_bus_if[i].resp_vld = mem_resp_vld[i];
        assign mem_bus_if[i].resp_data.data = mem_resp_data[i];
        assign mem_bus_if[i].resp_data.tag = mem_resp_tag[i];
        assign mem_resp_rdy[i] = mem_bus_if[i].resp_rdy;
    end

    xrv_cache #(
        .XLEN_P                 (XLEN_P),
        .INSTANCE_ID            (INSTANCE_ID),
        .CACHE_SIZE_P           (CACHE_SIZE_P),
        .LINE_SIZE_P            (LINE_SIZE_P),
        .NUM_BANKS_P            (NUM_BANKS_P),
        .NUM_WAYS_P             (NUM_WAYS_P),
        .WORD_SIZE_P            (WORD_SIZE_P),
        .NUM_REQS_P             (NUM_REQS_P),
        .NUM_MEM_PORTS_P        (NUM_MEM_PORTS_P),
        .CRSQ_SIZE_P            (CRSQ_SIZE_P),
        .MSHR_SIZE_P            (MSHR_SIZE_P),
        .MRSQ_SIZE_P            (MRSQ_SIZE_P),
        .MREQ_SIZE_P            (MREQ_SIZE_P),
        .TAG_WIDTH_P            (TAG_WIDTH_P),
        .UUID_WIDTH_P           (UUID_WIDTH_P),
        .IS_WRITEABLE_P         (IS_WRITEABLE_P),
        .HAS_WRITEBACK_P        (HAS_WRITEBACK_P),
        .HAS_DIRTY_BYTES_P      (HAS_DIRTY_BYTES_P),
        .CORE_OUT_BUF           (CORE_OUT_BUF),
        .MEM_OUT_BUF            (MEM_OUT_BUF)
    ) cache (
    `ifdef PERF_ENABLE
        .cache_perf             (cache_perf),
    `endif
        .clk_i                  (clk_i),
        .rst_i                  (rst_i),
        .core_bus_if            (core_bus_if),
        .mem_bus_if             (mem_bus_if)
    );

endmodule
