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


module xrv_cache_cluster #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                    = 32,
    parameter MEM_ADDR_WIDTH_P          = (XLEN_P == 32 ? 32 : 48),
    ////////////////////////////////////////////////////////////////////////////////
    parameter `STRING INSTANCE_ID    = "",

    parameter NUM_UNITS             = 1,
    parameter NUM_INPUTS            = 1,
    parameter TAG_SEL_IDX           = 0,

    // Number of requests per cycle
    parameter NUM_REQS_P              = 4,

    // Number of memory ports
    parameter NUM_MEM_PORTS_P             = 1,

    // Size of cache in bytes
    parameter CACHE_SIZE_P            = 32768,
    // Size of line inside a bank in bytes
    parameter LINE_SIZE_P             = 64,
    // Number of banks
    parameter NUM_BANKS_P             = 4,
    // Number of associative ways
    parameter NUM_WAYS_P              = 4,
    // Size of a word in bytes
    parameter WORD_SIZE_P             = 16,

    // Core Response Queue Size
    parameter CRSQ_SIZE_P             = 4,
    // Miss Reserv Queue Knob
    parameter MSHR_SIZE_P             = 16,
    // Memory Response Queue Size
    parameter MRSQ_SIZE_P             = 4,
    // Memory Request Queue Size
    parameter MREQ_SIZE_P             = 4,

    // Enable cache writeable
    parameter IS_WRITEABLE_P          = 1,

    // Enable cache writeback
    parameter HAS_WRITEBACK_P             = 0,

    // Enable dirty bytes on writeback
    parameter HAS_DIRTY_BYTES_P           = 0,

    // Replacement policy
    parameter REPL_POLICY               = `CACHE_REPL_CYCLIC,

    // Request debug identifier
    parameter UUID_WIDTH_P            = 0,

    // core request tag size
    parameter TAG_WIDTH_P             = UUID_WIDTH_P + 1,

    // core request flags
    parameter FLAGS_WIDTH_P           = 0,

    // enable bypass for non-cacheable addresses
    parameter NC_ENABLE             = 0,

    // Core response output buffer
    parameter CORE_OUT_BUF          = 3,

    // Memory request output buffer
    parameter MEM_OUT_BUF           = 3
 ) (
    input wire clk_i,
    input wire rst_i,

    // PERF
`ifdef PERF_ENABLE
    output cache_perf_t     cache_perf,
`endif

    xrv_cache_if.slave     core_bus_if [NUM_INPUTS * NUM_REQS_P],
    xrv_cache_if.master    mem_bus_if [NUM_MEM_PORTS_P]
);
    localparam NUM_CACHES = `XM_UP(NUM_UNITS);
    localparam PASSTHRU   = (NUM_UNITS == 0);
    localparam ARB_TAG_WIDTH_P = TAG_WIDTH_P + `XM_ARB_SEL_BITS(NUM_INPUTS, NUM_CACHES);

    localparam CACHE_MEM_TAG_WIDTH_P = `CACHE_MEM_TAG_WIDTH(MSHR_SIZE_P, NUM_BANKS_P, NUM_MEM_PORTS_P, UUID_WIDTH_P);
    localparam BYPASS_TAG_WIDTH_P = `CACHE_BYPASS_TAG_WIDTH(NUM_REQS_P, NUM_MEM_PORTS_P, LINE_SIZE_P, WORD_SIZE_P, ARB_TAG_WIDTH_P);
    localparam NC_TAG_WIDTH_P = `XM_MAX(CACHE_MEM_TAG_WIDTH_P, BYPASS_TAG_WIDTH_P) + 1;
    localparam MEM_TAG_WIDTH_P = PASSTHRU ? BYPASS_TAG_WIDTH_P : (NC_ENABLE ? NC_TAG_WIDTH_P : CACHE_MEM_TAG_WIDTH_P);

    `STATIC_ASSERT(NUM_INPUTS >= NUM_CACHES, ("invalid parameter"))

`ifdef PERF_ENABLE
    cache_perf_t perf_cache_unit[NUM_CACHES];
    `PERF_CACHE_ADD (cache_perf, perf_cache_unit, NUM_CACHES)
`endif

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (LINE_SIZE_P),
        .TAG_WIDTH_P        (MEM_TAG_WIDTH_P)
    ) cache_mem_bus_if[NUM_CACHES * NUM_MEM_PORTS_P]();

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (WORD_SIZE_P),
        .TAG_WIDTH_P        (ARB_TAG_WIDTH_P)
    ) arb_core_bus_if[NUM_CACHES * NUM_REQS_P]();

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_arb
        xrv_cache_if #(
            .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
            .DATA_SIZE_P        (WORD_SIZE_P),
            .TAG_WIDTH_P        (TAG_WIDTH_P)
        ) core_bus_tmp_if[NUM_INPUTS]();

        xrv_cache_if #(
            .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
            .DATA_SIZE_P        (WORD_SIZE_P),
            .TAG_WIDTH_P        (ARB_TAG_WIDTH_P)
        ) arb_core_bus_tmp_if[NUM_CACHES]();

        for (genvar j = 0; j < NUM_INPUTS; ++j) begin : g_core_bus_tmp_if
            `ASSIGN_XRV_CACHE_IF (core_bus_tmp_if[j], core_bus_if[j * NUM_REQS_P + i]);
        end

        xrv_mem_arb #(
            .NUM_INPUTS_P       (NUM_INPUTS),
            .NUM_OUTPUTS_P      (NUM_CACHES),
            .DATA_SIZE_P        (WORD_SIZE_P),
            .TAG_WIDTH_P        (TAG_WIDTH_P),
            .TAG_SEL_IDX        (TAG_SEL_IDX),
            .ARBITER_TYPE_P     ("R"),
            .REQ_OUT_BUF        ((NUM_INPUTS != NUM_CACHES) ? 2 : 0),
            .RSP_OUT_BUF        ((NUM_INPUTS != NUM_CACHES) ? CORE_OUT_BUF : 0)
        ) core_arb (
            .clk_i              (clk_i),
            .rst_i              (rst_i),
            .bus_in_if          (core_bus_tmp_if),
            .bus_out_if         (arb_core_bus_tmp_if)
        );

        for (genvar k = 0; k < NUM_CACHES; ++k) begin : g_arb_core_bus_if
            `ASSIGN_XRV_CACHE_IF (arb_core_bus_if[k * NUM_REQS_P + i], arb_core_bus_tmp_if[k]);
        end
    end

     for (genvar i = 0; i < NUM_CACHES; ++i) begin : g_cache_wrap
        xrv_cache_wrap #(
            .INSTANCE_ID        (`SFORMATF(("%s%0d", INSTANCE_ID, i))),
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
            .TAG_WIDTH_P        (ARB_TAG_WIDTH_P),
            .FLAGS_WIDTH_P      (FLAGS_WIDTH_P),
            .TAG_SEL_IDX        (TAG_SEL_IDX),
            .CORE_OUT_BUF       ((NUM_INPUTS != NUM_CACHES) ? 2 : CORE_OUT_BUF),
            .MEM_OUT_BUF        ((NUM_CACHES > 1) ? 2 : MEM_OUT_BUF),
            .NC_ENABLE          (NC_ENABLE),
            .PASSTHRU_P         (PASSTHRU)
        ) cache_wrap (
        `ifdef PERF_ENABLE
            .cache_perf  (perf_cache_unit[i]),
        `endif
            .clk_i       (clk_i),
            .rst_i       (rst_i),
            .core_bus_if (arb_core_bus_if[i * NUM_REQS_P +: NUM_REQS_P]),
            .mem_bus_if  (cache_mem_bus_if[i * NUM_MEM_PORTS_P +: NUM_MEM_PORTS_P])
        );
    end

    for (genvar i = 0; i < NUM_MEM_PORTS_P; ++i) begin : g_mem_bus_if
        xrv_cache_if #(
            .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
            .DATA_SIZE_P        (LINE_SIZE_P),
            .TAG_WIDTH_P        (MEM_TAG_WIDTH_P)
        ) arb_core_bus_tmp_if[NUM_CACHES]();

        xrv_cache_if #(
            .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
            .DATA_SIZE_P        (LINE_SIZE_P),
            .TAG_WIDTH_P        (MEM_TAG_WIDTH_P + `XM_ARB_SEL_BITS(NUM_CACHES, 1))
        ) mem_bus_tmp_if[1]();

        for (genvar j = 0; j < NUM_CACHES; ++j) begin : g_arb_core_bus_tmp_if
            `ASSIGN_XRV_CACHE_IF (arb_core_bus_tmp_if[j], cache_mem_bus_if[j * NUM_MEM_PORTS_P + i]);
        end

        xrv_mem_arb #(
            .NUM_INPUTS_P       (NUM_CACHES),
            .NUM_OUTPUTS_P      (1),
            .DATA_SIZE_P        (LINE_SIZE_P),
            .TAG_WIDTH_P        (MEM_TAG_WIDTH_P),
            .TAG_SEL_IDX        (TAG_SEL_IDX),
            .ARBITER_TYPE_P     ("R"),
            .REQ_OUT_BUF        ((NUM_CACHES > 1) ? MEM_OUT_BUF : 0),
            .RSP_OUT_BUF        ((NUM_CACHES > 1) ? 2 : 0)
        ) mem_arb (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .bus_in_if      (arb_core_bus_tmp_if),
            .bus_out_if     (mem_bus_tmp_if)
        );

        if (IS_WRITEABLE_P) begin : g_we
            `ASSIGN_XRV_CACHE_IF (mem_bus_if[i], mem_bus_tmp_if[0]);
        end else begin : g_ro
            `ASSIGN_XRV_CACHE_RO_IF (mem_bus_if[i], mem_bus_tmp_if[0]);
        end
    end

endmodule
