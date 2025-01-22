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


module xrv_cache_wrap #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                    = 32,
    parameter MEM_ADDR_WIDTH_P          = (XLEN_P == 32 ? 32 : 48),
    ////////////////////////////////////////////////////////////////////////////////
    parameter `STRING INSTANCE_ID       = "",
    
    parameter TAG_SEL_IDX               = 0,

    // Number of Word requests per cycle
    parameter NUM_REQS_P                = 4,

    // Number of memory ports
    parameter NUM_MEM_PORTS_P           = 1,

    // Size of cache in bytes
    parameter CACHE_SIZE_P              = 4096,
    // Size of line inside a bank in bytes
    parameter LINE_SIZE_P               = 64,
    // Number of banks
    parameter NUM_BANKS_P               = 4,
    // Number of associative ways
    parameter NUM_WAYS_P                = 4,
    // Size of a word in bytes
    parameter WORD_SIZE_P               = 16,

    // Core Response Queue Size
    parameter CRSQ_SIZE_P               = 4,
    // Miss Reserv Queue Knob
    parameter MSHR_SIZE_P               = 16,
    // Memory Response Queue Size
    parameter MRSQ_SIZE_P               = 4,
    // Memory Request Queue Size
    parameter MREQ_SIZE_P               = 4,

    // Enable cache writeable
    parameter IS_WRITEABLE_P            = 1,

    // Enable cache writeback
    parameter HAS_WRITEBACK_P           = 0,

    // Enable dirty bytes on writeback
    parameter HAS_DIRTY_BYTES_P         = 0,

    // Replacement policy
    parameter REPL_POLICY               = `CACHE_REPL_CYCLIC,

    // Request debug identifier
    parameter UUID_WIDTH_P              = 0,

    // core request tag size
    parameter TAG_WIDTH_P               = UUID_WIDTH_P + 1,

    // core request flags
    parameter FLAGS_WIDTH_P             = 0,

    // enable bypass for non-cacheable addresses
    parameter NC_ENABLE                 = 0,

    // Force bypass for all requests
    parameter PASSTHRU_P                = 0,

    // Core response output buffer
    parameter CORE_OUT_BUF              = 3,

    // Memory request output buffer
    parameter MEM_OUT_BUF               = 3
 ) (

    input wire clk_i,
    input wire rst_i,

    // PERF
`ifdef PERF_ENABLE
    output cache_perf_t     cache_perf,
`endif

    xrv_cache_if.slave     core_bus_if [NUM_REQS_P],
    xrv_cache_if.master    mem_bus_if [NUM_MEM_PORTS_P]
);

    `STATIC_ASSERT(NUM_BANKS_P == (1 << `XM_CLOG2(NUM_BANKS_P)), ("invalid parameter"))

    localparam CACHE_MEM_TAG_WIDTH_P = `CACHE_MEM_TAG_WIDTH(MSHR_SIZE_P, NUM_BANKS_P, NUM_MEM_PORTS_P, UUID_WIDTH_P);
    localparam BYPASS_TAG_WIDTH_P = `CACHE_BYPASS_TAG_WIDTH(NUM_REQS_P, NUM_MEM_PORTS_P, LINE_SIZE_P, WORD_SIZE_P, TAG_WIDTH_P);
    localparam NC_TAG_WIDTH_P = `XM_MAX(CACHE_MEM_TAG_WIDTH_P, BYPASS_TAG_WIDTH_P) + 1;
    localparam MEM_TAG_WIDTH_P = PASSTHRU_P ? BYPASS_TAG_WIDTH_P : (NC_ENABLE ? NC_TAG_WIDTH_P : CACHE_MEM_TAG_WIDTH_P);
    localparam BYPASS_ENABLE_LP = (NC_ENABLE || PASSTHRU_P);

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (WORD_SIZE_P),
        .TAG_WIDTH_P (      TAG_WIDTH_P)
    ) core_bus_cache_if[NUM_REQS_P]();

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (LINE_SIZE_P),
        .TAG_WIDTH_P        (CACHE_MEM_TAG_WIDTH_P)
    ) mem_bus_cache_if[NUM_MEM_PORTS_P]();

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (LINE_SIZE_P),
        .TAG_WIDTH_P        (MEM_TAG_WIDTH_P)
    ) mem_bus_tmp_if[NUM_MEM_PORTS_P]();

    if (BYPASS_ENABLE_LP) begin : g_bypass

        xrv_cache_bypass #(
            .NUM_REQS_P         (NUM_REQS_P),
            .NUM_MEM_PORTS_P    (NUM_MEM_PORTS_P),
            .TAG_SEL_IDX        (TAG_SEL_IDX),

            .CACHE_ENABLE       (!PASSTHRU_P),

            .WORD_SIZE_P        (WORD_SIZE_P),
            .LINE_SIZE_P        (LINE_SIZE_P),

            .CORE_ADDR_WIDTH    (CACHE_WORD_ADDR_WIDTH_LP),
            .CORE_TAG_WIDTH_P   (TAG_WIDTH_P),

            .MEM_ADDR_WIDTH     (CACHE_MEM_ADDR_WIDTH_LP),
            .MEM_TAG_IN_WIDTH   (CACHE_MEM_TAG_WIDTH_P),

            .UUID_WIDTH_P       (UUID_WIDTH_P),

            .CORE_OUT_BUF       (CORE_OUT_BUF),
            .MEM_OUT_BUF        (MEM_OUT_BUF)
        ) cache_bypass (
            .clk_i              (clk_i),
            .rst_i              (rst_i),

            .core_bus_in_if     (core_bus_if),
            .core_bus_out_if    (core_bus_cache_if),

            .mem_bus_in_if      (mem_bus_cache_if),
            .mem_bus_out_if     (mem_bus_tmp_if)
        );

    end else begin : g_no_bypass

        for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_bus_cache_if
            `ASSIGN_XRV_CACHE_IF (core_bus_cache_if[i], core_bus_if[i]);
        end

        for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_mem_bus_tmp_if
            `ASSIGN_XRV_CACHE_IF (mem_bus_tmp_if[i], mem_bus_cache_if[i]);
        end
    end

    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_mem_bus_if
        if (IS_WRITEABLE_P) begin : g_we
            `ASSIGN_XRV_CACHE_IF (mem_bus_if[i], mem_bus_tmp_if[i]);
        end else begin : g_ro
            `ASSIGN_XRV_CACHE_RO_IF (mem_bus_if[i], mem_bus_tmp_if[i]);
        end
    end

    if (PASSTHRU_P == 0) begin : g_cache

        xrv_cache #(
            .INSTANCE_ID        (INSTANCE_ID),
            .XLEN_P             (XLEN_P),
            .CACHE_SIZE_P       (CACHE_SIZE_P),
            .LINE_SIZE_P        (LINE_SIZE_P),
            .NUM_BANKS_P        (NUM_BANKS_P),
            .NUM_WAYS_P         (NUM_WAYS_P),
            .WORD_SIZE_P        (WORD_SIZE_P),
            .NUM_REQS_P         (NUM_REQS_P),
            .NUM_MEM_PORTS_P    (NUM_MEM_PORTS_P),
            .IS_WRITEABLE_P     (IS_WRITEABLE_P),
            .HAS_WRITEBACK_P    (HAS_WRITEBACK_P),
            .HAS_DIRTY_BYTES_P  (HAS_DIRTY_BYTES_P),
            .REPL_POLICY        (REPL_POLICY),
            .CRSQ_SIZE_P        (CRSQ_SIZE_P),
            .MSHR_SIZE_P        (MSHR_SIZE_P),
            .MRSQ_SIZE_P        (MRSQ_SIZE_P),
            .MREQ_SIZE_P        (MREQ_SIZE_P),
            .UUID_WIDTH_P       (UUID_WIDTH_P),
            .TAG_WIDTH_P        (TAG_WIDTH_P),
            .FLAGS_WIDTH_P      (FLAGS_WIDTH_P),
            .CORE_OUT_BUF       (BYPASS_ENABLE_LP ? 1 : CORE_OUT_BUF),
            .MEM_OUT_BUF        (BYPASS_ENABLE_LP ? 1 : MEM_OUT_BUF)
        ) cache (
            .clk_i                (clk_i),
            .rst_i              (rst_i),
        `ifdef PERF_ENABLE
            .cache_perf         (cache_perf),
        `endif
            .core_bus_if        (core_bus_cache_if),
            .mem_bus_if         (mem_bus_cache_if)
        );

    end else begin : g_passthru

        for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_bus_cache_if
            `UNUSED_XRV_CACHE_IF (core_bus_cache_if[i])
        end

        for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_mem_bus_cache_if
            `INIT_XRV_CACHE_IF (mem_bus_cache_if[i])
        end

    `ifdef PERF_ENABLE
        assign cache_perf = '0;
    `endif

    end

`ifdef DBG_TRACE_CACHE
    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_trace_core
        always @(posedge clk_i) begin
            if (core_bus_if[i].req_valid && core_bus_if[i].req_ready) begin
                if (core_bus_if[i].req_data.rw) begin
                    `TRACE(2, ("%t: %s core-wr-req[%0d]: addr=0x%0h, tag=0x%0h, req_idx=%0d, byteen=0x%h, data=0x%h (#%0d)\n", $time, INSTANCE_ID, i, `TO_FULL_ADDR(core_bus_if[i].req_data.addr), core_bus_if[i].req_data.tag.value, i, core_bus_if[i].req_data.byteen, core_bus_if[i].req_data.data, core_bus_if[i].req_data.tag.uuid))
                end else begin
                    `TRACE(2, ("%t: %s core-rd-req[%0d]: addr=0x%0h, tag=0x%0h, req_idx=%0d (#%0d)\n", $time, INSTANCE_ID, i, `TO_FULL_ADDR(core_bus_if[i].req_data.addr), core_bus_if[i].req_data.tag.value, i, core_bus_if[i].req_data.tag.uuid))
                end
            end
            if (core_bus_if[i].rsp_valid && core_bus_if[i].rsp_ready) begin
                `TRACE(2, ("%t: %s core-rd-rsp[%0d]: tag=0x%0h, req_idx=%0d, data=0x%h (#%0d)\n", $time, INSTANCE_ID, i, core_bus_if[i].rsp_data.tag.value, i, core_bus_if[i].rsp_data.data, core_bus_if[i].rsp_data.tag.uuid))
            end
        end
    end

    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_trace_mem
        always @(posedge clk_i) begin
            if (mem_bus_if[i].req_valid && mem_bus_if[i].req_ready) begin
                if (mem_bus_if[i].req_data.rw) begin
                    `TRACE(2, ("%t: %s mem-wr-req[%0d]: addr=0x%0h, tag=0x%0h, byteen=0x%h, data=0x%h (#%0d)\n",
                        $time, INSTANCE_ID, i, `TO_FULL_ADDR(mem_bus_if[i].req_data.addr), mem_bus_if[i].req_data.tag.value, mem_bus_if[i].req_data.byteen, mem_bus_if[i].req_data.data, mem_bus_if[i].req_data.tag.uuid))
                end else begin
                    `TRACE(2, ("%t: %s mem-rd-req[%0d]: addr=0x%0h, tag=0x%0h (#%0d)\n",
                        $time, INSTANCE_ID, i, `TO_FULL_ADDR(mem_bus_if[i].req_data.addr), mem_bus_if[i].req_data.tag.value, mem_bus_if[i].req_data.tag.uuid))
                end
            end
            if (mem_bus_if[i].rsp_valid && mem_bus_if[i].rsp_ready) begin
                `TRACE(2, ("%t: %s mem-rd-rsp[%0d]: data=0x%h, tag=0x%0h (#%0d)\n",
                    $time, INSTANCE_ID, i, mem_bus_if[i].rsp_data.data, mem_bus_if[i].rsp_data.tag.value, mem_bus_if[i].rsp_data.tag.uuid))
            end
        end
    end
`endif

endmodule
