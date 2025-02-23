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
`include "pkg/amoeba_gpu_pkg.sv"

`ifdef EXT_F_ENABLE
`include "xrv_vx_fpu_define.vh"
`endif

module xrv_vx_core_top import amoeba_gpu_pkg::*; #(
    parameter CORE_ID           = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P            = 64,
    parameter MEM_ADDR_WIDTH_P  = (XLEN_P == 64 ? 48 : 32),
    parameter PC_WIDTH_P        = XLEN_P,
    parameter NUM_WARPS_P       = 4,
    parameter NUM_THREADS_P     = 4,
    parameter WID_WIDTH_P       = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P       = `XM_CLOG2(NUM_THREADS_P),
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P      = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P     = 2,
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_LSU_BLOCKS_P  = 1,
    parameter NUM_ALU_BLOCKS_P  = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_LSU_LANES_P   = NUM_THREADS_P,
    ////////////////////////////////////////////////////////////////////////////////
    parameter L1_LINE_SIZE_P    = 64,
    ////////////////////////////////////////////////////////////////////////////////
    // LSU 
    ////////////////////////////////////////////////////////////////////////////////
    parameter LSU_WORD_SIZE_P       = XLEN_P / 8,
    // LSU line size
    parameter LSU_LINE_SIZE_P       = `XM_MIN(NUM_LSU_LANES_P * (XLEN_P / 8), L1_LINE_SIZE_P),
    // Size of LSU Core Request Queue
    parameter LSUQ_IN_SIZE_P        = (2 * (NUM_THREADS_P / NUM_LSU_LANES_P)),
    // Size of LSU Memory Request Queue
    parameter LSUQ_OUT_SIZE_P       =  `XM_MAX(LSUQ_IN_SIZE_P, LSU_LINE_SIZE_P / (XLEN_P / 8)),
    parameter LSU_ADDR_WIDTH_P	    = (MEM_ADDR_WIDTH_P - `XM_CLOG2(LSU_WORD_SIZE_P)),
    parameter LSU_MEM_BATCHES_P     = 1,
    parameter LSU_TAG_ID_BITS_P     = (`XM_CLOG2(LSUQ_IN_SIZE_P) + `XM_CLOG2(LSU_MEM_BATCHES_P)),
    parameter LSU_TAG_WIDTH_P       = (UUID_WIDTH_P + LSU_TAG_ID_BITS_P),
    parameter LSU_NUM_REQS_P        = NUM_LSU_BLOCKS_P * NUM_LSU_LANES_P,
    ////////////////////////////////////////////////////////////////////////////////
    // ICache 
    ////////////////////////////////////////////////////////////////////////////////
    // Word size in bytes
    parameter ICACHE_WORD_SIZE_P	= 4,
    parameter ICACHE_ADDR_WIDTH_P	= (MEM_ADDR_WIDTH_P - `XM_CLOG2(ICACHE_WORD_SIZE_P)),
    // Block size in bytes
    parameter ICACHE_LINE_SIZE_P	= L1_LINE_SIZE_P,
    // Core request tag Id bits
    parameter ICACHE_TAG_ID_BITS_P	= WID_WIDTH_P,
    // Core request tag bits
    parameter ICACHE_TAG_WIDTH_P	= (UUID_WIDTH_P + ICACHE_TAG_ID_BITS_P),
    ////////////////////////////////////////////////////////////////////////////////
    // DCache 
    ////////////////////////////////////////////////////////////////////////////////
    parameter DCACHE_WORD_SIZE_P    = LSU_LINE_SIZE_P,
    parameter DCACHE_ADDR_WIDTH_P	= (MEM_ADDR_WIDTH_P - `XM_CLOG2(DCACHE_WORD_SIZE_P)),
    // Block size in bytes
    localparam DCACHE_LINE_SIZE_P 	= L1_LINE_SIZE_P,
    // Input request size (using coalesced memory blocks)
    parameter DCACHE_CHANNELS_P	    = `XM_UP((NUM_LSU_LANES_P * LSU_WORD_SIZE_P) / DCACHE_WORD_SIZE_P),
    parameter DCACHE_NUM_REQS_P	    = NUM_LSU_BLOCKS_P * DCACHE_CHANNELS_P,
    // Core request tag Id bits
    parameter DCACHE_MERGED_REQS_P  = (NUM_LSU_LANES_P * LSU_WORD_SIZE_P) / DCACHE_WORD_SIZE_P,
    parameter DCACHE_MEM_BATCHES_P  = `XM_CDIV(DCACHE_MERGED_REQS_P, DCACHE_CHANNELS_P),
    parameter DCACHE_TAG_ID_BITS_P  = (`XM_CLOG2(LSUQ_OUT_SIZE_P) + `XM_CLOG2(DCACHE_MEM_BATCHES_P)),
    // Core request tag bits
    parameter DCACHE_TAG_WIDTH_P    = (UUID_WIDTH_P + DCACHE_TAG_ID_BITS_P)
    ////////////////////////////////////////////////////////////////////////////////
) (
    // Clock
    input wire                                                      clk_i,
    input wire                                                      rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input wire                                                      vx_mode_en_i,
    ////////////////////////////////////////////////////////////////////////////////
    input wire                                                      dcr_write_vld,
    input wire [VX_DCR_ADDR_WIDTH-1:0]                              dcr_write_addr,
    input wire [VX_DCR_DATA_WIDTH-1:0]                              dcr_write_data,
    ////////////////////////////////////////////////////////////////////////////////
    output wire [DCACHE_NUM_REQS_P-1:0]                             dcache_req_vld,
    output wire [DCACHE_NUM_REQS_P-1:0]                             dcache_req_rw,
    output wire [DCACHE_NUM_REQS_P-1:0][DCACHE_WORD_SIZE_P-1:0]     dcache_req_byteen,
    output wire [DCACHE_NUM_REQS_P-1:0][DCACHE_ADDR_WIDTH_P-1:0]    dcache_req_addr,
    output wire [DCACHE_NUM_REQS_P-1:0][VX_MEM_REQ_FLAGS_WIDTH-1:0] dcache_req_flags,
    output wire [DCACHE_NUM_REQS_P-1:0][DCACHE_WORD_SIZE_P*8-1:0]   dcache_req_data,
    output wire [DCACHE_NUM_REQS_P-1:0][DCACHE_TAG_WIDTH_P-1:0]     dcache_req_tag,
    input  wire [DCACHE_NUM_REQS_P-1:0]                             dcache_req_rdy,
    ////////////////////////////////////////////////////////////////////////////////
    input wire  [DCACHE_NUM_REQS_P-1:0]                             dcache_resp_vld,
    input wire  [DCACHE_NUM_REQS_P-1:0][DCACHE_WORD_SIZE_P*8-1:0]   dcache_resp_data,
    input wire  [DCACHE_NUM_REQS_P-1:0][DCACHE_TAG_WIDTH_P-1:0]     dcache_resp_tag,
    output wire [DCACHE_NUM_REQS_P-1:0]                             dcache_resp_rdy,
    ////////////////////////////////////////////////////////////////////////////////
    output wire                                 icache_req_vld,
    output wire                                 icache_req_rw,
    output wire [ICACHE_WORD_SIZE_P-1:0]        icache_req_byteen,
    output wire [ICACHE_ADDR_WIDTH_P-1:0]       icache_req_addr,
    output wire [ICACHE_WORD_SIZE_P*8-1:0]      icache_req_data,
    output wire [ICACHE_TAG_WIDTH_P-1:0]        icache_req_tag,
    input  wire                                 icache_req_rdy,
    ////////////////////////////////////////////////////////////////////////////////
    input wire                                  icache_resp_vld,
    input wire  [ICACHE_WORD_SIZE_P*8-1:0]      icache_resp_data,
    input wire  [ICACHE_TAG_WIDTH_P-1:0]        icache_resp_tag,
    output wire                                 icache_resp_rdy,

`ifdef GBAR_ENABLE
    output wire                             gbar_req_vld,
    output wire [`NB_WIDTH-1:0]             gbar_req_id,
    output wire [`NC_WIDTH-1:0]             gbar_req_size_m1,
    output wire [`NC_WIDTH-1:0]             gbar_req_core_id,
    input wire                              gbar_req_rdy,
    input wire                              gbar_resp_vld,
    input wire [`NB_WIDTH-1:0]              gbar_resp_id,
`endif
    // Status
    output wire                             busy
);

`ifdef GBAR_ENABLE
    xrv_vx_gbar_bus_if gbar_bus_if();

    assign gbar_req_vld = gbar_bus_if.req_vld;
    assign gbar_req_id = gbar_bus_if.req_id;
    assign gbar_req_size_m1 = gbar_bus_if.req_size_m1;
    assign gbar_req_core_id =  gbar_bus_if.req_core_id;
    assign gbar_bus_if.req_rdy = gbar_req_rdy;
    assign gbar_bus_if.resp_vld = gbar_resp_vld;
    assign gbar_bus_if.resp_id = gbar_resp_id;
`endif

    xrv_vx_dcr_bus_if dcr_bus_if();

    assign dcr_bus_if.write_vld = dcr_write_vld;
    assign dcr_bus_if.write_addr = dcr_write_addr;
    assign dcr_bus_if.write_data = dcr_write_data;

    xrv_cache_if #(
        .DATA_SIZE_P    (DCACHE_WORD_SIZE_P),
        .TAG_WIDTH_P    (DCACHE_TAG_WIDTH_P)
    ) dcache_bus_if[DCACHE_NUM_REQS_P]();

    for (genvar i = 0; i < DCACHE_NUM_REQS_P; ++i) begin
        assign dcache_req_vld[i] = dcache_bus_if[i].req_vld;
        assign dcache_req_rw[i] = dcache_bus_if[i].req_data.rw;
        assign dcache_req_byteen[i] = dcache_bus_if[i].req_data.byteen;
        assign dcache_req_addr[i] = dcache_bus_if[i].req_data.addr;
        assign dcache_req_flags[i] = dcache_bus_if[i].req_data.flags;
        assign dcache_req_data[i] = dcache_bus_if[i].req_data.data;
        assign dcache_req_tag[i] = dcache_bus_if[i].req_data.tag;
        assign dcache_bus_if[i].req_rdy = dcache_req_rdy[i];

        assign dcache_bus_if[i].resp_vld = dcache_resp_vld[i];
        assign dcache_bus_if[i].resp_data.tag = dcache_resp_tag[i];
        assign dcache_bus_if[i].resp_data.data = dcache_resp_data[i];
        assign dcache_resp_rdy[i] = dcache_bus_if[i].resp_rdy;
    end

    xrv_cache_if #(
        .DATA_SIZE_P    (ICACHE_WORD_SIZE_P),
        .TAG_WIDTH_P    (ICACHE_TAG_WIDTH_P)
    ) icache_bus_if();

    assign icache_req_vld = icache_bus_if.req_vld;
    assign icache_req_rw = icache_bus_if.req_data.rw;
    assign icache_req_byteen = icache_bus_if.req_data.byteen;
    assign icache_req_addr = icache_bus_if.req_data.addr;
    assign icache_req_data = icache_bus_if.req_data.data;
    assign icache_req_tag = icache_bus_if.req_data.tag;
    assign icache_bus_if.req_rdy = icache_req_rdy;
    `XM_UNUSED_VAR (icache_bus_if.req_data.flags)

    assign icache_bus_if.resp_vld = icache_resp_vld;
    assign icache_bus_if.resp_data.tag = icache_resp_tag;
    assign icache_bus_if.resp_data.data = icache_resp_data;
    assign icache_resp_rdy = icache_bus_if.resp_rdy;

`ifdef PERF_ENABLE
    xrv_vx_mem_perf_if mem_perf_if();
    assign mem_perf_if.icache  = '0;
    assign mem_perf_if.dcache  = '0;
    assign mem_perf_if.l2cache = '0;
    assign mem_perf_if.l3cache = '0;
    assign mem_perf_if.lmem    = '0;
    assign mem_perf_if.mem     = '0;
`endif

`ifdef SCOPE
    wire [0:0] scope_rst_i_w = 1'b0;
    wire [0:0] scope_bus_in_w = 1'b0;
    wire [0:0] scope_bus_out_w;
    `XM_UNUSED_VAR (scope_bus_out_w)
`endif

    xrv_vx_core #(
        .INSTANCE_ID        (`SFORMATF(("core"))),
        .CORE_ID            (CORE_ID),
        ////////////////////////////////////////////////////////////////////////////////
        .XLEN_P             (XLEN_P),
        .NUM_WARPS_P        (NUM_WARPS_P),
        .NUM_THREADS_P      (NUM_THREADS_P),
        ////////////////////////////////////////////////////////////////////////////////
        .ISSUE_WIDTH_P      (ISSUE_WIDTH_P)
        ////////////////////////////////////////////////////////////////////////////////
    ) core (
        `SCOPE_IO_BIND (0)
        .clk_i              (clk_i),
        .rst_i              (rst_i),

        .vx_mode_en_i       (vx_mode_en_i),

    `ifdef PERF_ENABLE
        .mem_perf_if    (mem_perf_if),
    `endif

        .dcr_bus_if     (dcr_bus_if),

        .dcache_bus_if  (dcache_bus_if),

        .icache_bus_if  (icache_bus_if),

    `ifdef GBAR_ENABLE
        .gbar_bus_if    (gbar_bus_if),
    `endif

        .busy           (busy)
    );

endmodule
