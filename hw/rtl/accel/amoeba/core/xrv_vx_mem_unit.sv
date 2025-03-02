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

module xrv_vx_mem_unit import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_LSU_LANES_P       = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = "inv",
    parameter MEM_ADDR_WIDTH_P      = (XLEN_P == 32 ? 32 : 48),
    parameter NUM_THREADS_P         = 4,
    parameter NUM_WARPS_P           = 4,
    parameter WID_WIDTH_P           = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P           = `XM_CLOG2(NUM_THREADS_P),
    parameter UUID_WIDTH_P          = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_LSU_BLOCKS_P      = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    // LSU 
    ////////////////////////////////////////////////////////////////////////////////
    parameter LSU_WORD_SIZE_P       = XLEN_P / 8,
    // LSU line size
    parameter LSU_LINE_SIZE_P       = "inv",
    // Size of LSU Core Request Queue
    parameter LSUQ_IN_SIZE_P        = (2 * (NUM_THREADS_P / NUM_LSU_LANES_P)),
    // Size of LSU Memory Request Queue
    parameter LSUQ_OUT_SIZE_P       = `XM_MAX(LSUQ_IN_SIZE_P, LSU_LINE_SIZE_P / (XLEN_P / 8)),
    parameter LSU_ADDR_WIDTH_P	    = (MEM_ADDR_WIDTH_P - `XM_CLOG2(LSU_WORD_SIZE_P)),
    parameter LSU_MEM_BATCHES_P     = 1,
    parameter LSU_TAG_ID_BITS_P     = (`XM_CLOG2(LSUQ_IN_SIZE_P) + `XM_CLOG2(LSU_MEM_BATCHES_P)),
    parameter LSU_TAG_WIDTH_P       = (UUID_WIDTH_P + LSU_TAG_ID_BITS_P),
    parameter LSU_NUM_REQS_P        = NUM_LSU_BLOCKS_P * NUM_LSU_LANES_P,
    ////////////////////////////////////////////////////////////////////////////////
    // DCache 
    ////////////////////////////////////////////////////////////////////////////////
    parameter DCACHE_WORD_SIZE_P    = LSU_LINE_SIZE_P,
    parameter DCACHE_ADDR_WIDTH_P	= (MEM_ADDR_WIDTH_P - `XM_CLOG2(DCACHE_WORD_SIZE_P)),
    // Input request size (using coalesced memory blocks)
    parameter DCACHE_CHANNELS_P	    = `XM_UP((NUM_LSU_LANES_P * LSU_WORD_SIZE_P) / DCACHE_WORD_SIZE_P),
    parameter DCACHE_NUM_REQS_P	    = NUM_LSU_BLOCKS_P * DCACHE_CHANNELS_P,
    // Core request tag Id bits
    parameter DCACHE_MERGED_REQS_P  = (NUM_LSU_LANES_P * LSU_WORD_SIZE_P) / DCACHE_WORD_SIZE_P,
    parameter DCACHE_MEM_BATCHES_P  = `XM_CDIV(DCACHE_MERGED_REQS_P, DCACHE_CHANNELS_P),
    parameter DCACHE_TAG_ID_BITS_P  = (`XM_CLOG2(LSUQ_OUT_SIZE_P) + `XM_CLOG2(DCACHE_MEM_BATCHES_P)),
    // Core request tag bits
    parameter DCACHE_TAG_WIDTH_P    = (UUID_WIDTH_P + DCACHE_TAG_ID_BITS_P)
) (
    input wire              clk_i,
    input wire              rst_i,

`ifdef PERF_ENABLE
    output cache_perf_t     lmem_perf,
`endif

    xrv_vx_lsu_mem_if.slave lsu_mem_if [NUM_LSU_BLOCKS_P],
    xrv_cache_if.master     dcache_bus_if [DCACHE_NUM_REQS_P]
);
    xrv_vx_lsu_mem_if #(
        .NUM_LANES_P        (NUM_LSU_LANES_P),
        .DATA_SIZE_P        (LSU_WORD_SIZE_P),
        .TAG_WIDTH_P        (LSU_TAG_WIDTH_P),
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .UUID_WIDTH_P       (UUID_WIDTH_P)
    ) lsu_dcache_if[NUM_LSU_BLOCKS_P]();

`ifdef LMEM_ENABLE

    `STATIC_ASSERT(`IS_DIVISBLE((1 << `LMEM_LOG_SIZE), `MEM_BLOCK_SIZE), ("invld parameter"))
    `STATIC_ASSERT(0 == (`LMEM_BASE_ADDR % (1 << `LMEM_LOG_SIZE)), ("invld parameter"))

    localparam LMEM_ADDR_WIDTH = `LMEM_LOG_SIZE - `CLOG2(LSU_WORD_SIZE_P);

     xrv_vx_lsu_mem_if #(
        .NUM_LANES_P        (NUM_LSU_LANES_P),
        .DATA_SIZE_P        (LSU_WORD_SIZE_P),
        .TAG_WIDTH_P        (LSU_TAG_WIDTH_P),
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .UUID_WIDTH_P       (UUID_WIDTH_P)
    ) lsu_lmem_if[NUM_LSU_BLOCKS_P]();

    for (genvar i = 0; i < NUM_LSU_BLOCKS_P; ++i) begin : g_lmem_switches
        xrv_vx_lmem_switch #(
            .REQ0_OUT_BUF (1),
            .REQ1_OUT_BUF (0),
            .RSP_OUT_BUF  (1),
            .ARBITER      ("P")
        ) lmem_switch (
            .clk_i          (clk_i),
            .rst_i        (rst_i),
            .lsu_in_if    (lsu_mem_if[i]),
            .global_out_if(lsu_dcache_if[i]),
            .local_out_if (lsu_lmem_if[i])
        );
    end

    xrv_cache_if #(
        .DATA_SIZE (LSU_WORD_SIZE_P),
        .TAG_WIDTH (LSU_TAG_WIDTH)
    ) lmem_bus_if[LSU_NUM_REQS]();

    for (genvar i = 0; i < NUM_LSU_BLOCKS_P; ++i) begin : g_lmem_adapters
        xrv_cache_if #(
            .DATA_SIZE (LSU_WORD_SIZE_P),
            .TAG_WIDTH (LSU_TAG_WIDTH)
        ) lmem_bus_tmp_if[NUM_LSU_LANES_P]();

        xrv_vx_lsu_adapter #(
            .NUM_LANES    (NUM_LSU_LANES_P),
            .DATA_SIZE    (LSU_WORD_SIZE_P),
            .TAG_WIDTH    (LSU_TAG_WIDTH),
            .TAG_SEL_BITS (LSU_TAG_WIDTH - UUID_WIDTH_P),
            .ARBITER      ("P"),
            .REQ_OUT_BUF  (3),
            .RSP_OUT_BUF  (2)
        ) lmem_adapter (
            .clk_i        (clk_i),
            .rst_i      (rst_i),
            .lsu_mem_if (lsu_lmem_if[i]),
            .mem_bus_if (lmem_bus_tmp_if)
        );

        for (genvar j = 0; j < NUM_LSU_LANES_P; ++j) begin : g_lmem_bus_if
            `ASSIGN_XRV_CACHE_IF (lmem_bus_if[i * NUM_LSU_LANES_P + j], lmem_bus_tmp_if[j]);
        end
    end

    xrv_vx_local_mem #(
        .INSTANCE_ID(`SFORMATF(("%s-lmem", INSTANCE_ID))),
        .SIZE       (1 << `LMEM_LOG_SIZE),
        .NUM_REQS   (LSU_NUM_REQS),
        .NUM_BANKS  (`LMEM_NUM_BANKS),
        .WORD_SIZE  (LSU_WORD_SIZE_P),
        .ADDR_WIDTH (LMEM_ADDR_WIDTH),
        .UUID_WIDTH (UUID_WIDTH_P),
        .TAG_WIDTH  (LSU_TAG_WIDTH),
        .OUT_BUF    (3)
    ) local_mem (
        .clk_i        (clk_i),
        .rst_i      (rst_i),
    `ifdef PERF_ENABLE
        .lmem_perf  (lmem_perf),
    `endif
        .mem_bus_if (lmem_bus_if)
    );

`else

`ifdef PERF_ENABLE
    assign lmem_perf = '0;
`endif
    for (genvar i = 0; i < NUM_LSU_BLOCKS_P; ++i) begin : g_lsu_dcache_if
        `ASSIGN_XRV_CACHE_IF (lsu_dcache_if[i], lsu_mem_if[i]);
    end

`endif

    xrv_vx_lsu_mem_if #(
        .NUM_LANES_P        (DCACHE_CHANNELS_P),
        .DATA_SIZE_P        (DCACHE_WORD_SIZE_P),
        .TAG_WIDTH_P        (DCACHE_TAG_WIDTH_P),
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .UUID_WIDTH_P       (UUID_WIDTH_P)
    ) dcache_coalesced_if[NUM_LSU_BLOCKS_P]();

    if ((NUM_LSU_LANES_P > 1) && (LSU_WORD_SIZE_P != DCACHE_WORD_SIZE_P)) begin : g_enabled

        for (genvar i = 0; i < NUM_LSU_BLOCKS_P; ++i) begin : g_coalescers
            xrv_mem_coalescer #(
                .INSTANCE_ID    (`SFORMATF(("%s-coalescer%0d", INSTANCE_ID, i))),
                .NUM_REQS       (NUM_LSU_LANES_P),
                .DATA_IN_SIZE   (LSU_WORD_SIZE_P),
                .DATA_OUT_SIZE  (DCACHE_WORD_SIZE_P),
                .ADDR_WIDTH     (LSU_ADDR_WIDTH_P),
                .FLAGS_WIDTH    (VX_MEM_REQ_FLAGS_WIDTH),
                .TAG_WIDTH      (LSU_TAG_WIDTH_P),
                .UUID_WIDTH     (UUID_WIDTH_P),
                .QUEUE_SIZE     (LSUQ_OUT_SIZE_P)
            ) mem_coalescer (
                .clk_i            (clk_i),
                .rst_i          (rst_i),

                // Input request
                .in_req_vld   (lsu_dcache_if[i].req_vld),
                .in_req_mask    (lsu_dcache_if[i].req_data.mask),
                .in_req_rw      (lsu_dcache_if[i].req_data.rw),
                .in_req_be  (lsu_dcache_if[i].req_data.be),
                .in_req_addr    (lsu_dcache_if[i].req_data.addr),
                .in_req_flags   (lsu_dcache_if[i].req_data.flags),
                .in_req_data    (lsu_dcache_if[i].req_data.data),
                .in_req_tag     (lsu_dcache_if[i].req_data.tag),
                .in_req_rdy   (lsu_dcache_if[i].req_rdy),

                // Input response
                .in_resp_vld   (lsu_dcache_if[i].resp_vld),
                .in_resp_mask    (lsu_dcache_if[i].resp_data.mask),
                .in_resp_data    (lsu_dcache_if[i].resp_data.data),
                .in_resp_tag     (lsu_dcache_if[i].resp_data.tag),
                .in_resp_rdy   (lsu_dcache_if[i].resp_rdy),

                // Output request
                .out_req_vld  (dcache_coalesced_if[i].req_vld),
                .out_req_mask   (dcache_coalesced_if[i].req_data.mask),
                .out_req_rw     (dcache_coalesced_if[i].req_data.rw),
                .out_req_be (dcache_coalesced_if[i].req_data.be),
                .out_req_addr   (dcache_coalesced_if[i].req_data.addr),
                .out_req_flags  (dcache_coalesced_if[i].req_data.flags),
                .out_req_data   (dcache_coalesced_if[i].req_data.data),
                .out_req_tag    (dcache_coalesced_if[i].req_data.tag),
                .out_req_rdy  (dcache_coalesced_if[i].req_rdy),

                // Output response
                .out_resp_vld  (dcache_coalesced_if[i].resp_vld),
                .out_resp_mask   (dcache_coalesced_if[i].resp_data.mask),
                .out_resp_data   (dcache_coalesced_if[i].resp_data.data),
                .out_resp_tag    (dcache_coalesced_if[i].resp_data.tag),
                .out_resp_rdy  (dcache_coalesced_if[i].resp_rdy)
            );
        end

    end else begin : g_passthru

        for (genvar i = 0; i < NUM_LSU_BLOCKS_P; ++i) begin : g_dcache_coalesced_if
            `ASSIGN_XRV_CACHE_IF (dcache_coalesced_if[i], lsu_dcache_if[i]);
        end

    end

    for (genvar i = 0; i < NUM_LSU_BLOCKS_P; ++i) begin : g_dcache_adapters

        xrv_cache_if #(
            .DATA_SIZE_P        (DCACHE_WORD_SIZE_P),
            .TAG_WIDTH_P        (DCACHE_TAG_WIDTH_P),
            .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P)
        ) dcache_bus_tmp_if[DCACHE_CHANNELS_P]();

        xrv_vx_lsu_adapter #(
            .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
            .NUM_LANES          (DCACHE_CHANNELS_P),
            .DATA_SIZE          (DCACHE_WORD_SIZE_P),
            .TAG_WIDTH          (DCACHE_TAG_WIDTH_P),
            .TAG_SEL_BITS       (DCACHE_TAG_WIDTH_P - UUID_WIDTH_P),
            .ARBITER            ("P"),
            .REQ_OUT_BUF        (0),
            .RSP_OUT_BUF        (0)
        ) dcache_adapter (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .lsu_mem_if     (dcache_coalesced_if[i]),
            .mem_bus_if     (dcache_bus_tmp_if)
        );

        for (genvar j = 0; j < DCACHE_CHANNELS_P; ++j) begin : g_dcache_bus_if
            `ASSIGN_XRV_CACHE_IF (dcache_bus_if[i * DCACHE_CHANNELS_P + j], dcache_bus_tmp_if[j]);
        end

    end

endmodule
