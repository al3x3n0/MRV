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

`include "subsystems/xrv_ccluster/defines.svh"
`include "xm_macro.svh"


module xrv_cores_cluster #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter CLUSTER_ID            = 0,
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    // Core configuration
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_THREADS_P         = 8,
    parameter XLEN_P                = 32,
    parameter MEM_ADDR_WIDTH_P      = (XLEN_P == 32 ? 32 : 48),
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P          = 3,
    ////////////////////////////////////////////////////////////////////////////////
    // Socket configuration
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_SOCKETS_P         = 4,
    parameter SOCKET_SIZE_P         = 4,
    ////////////////////////////////////////////////////////////////////////////////
    parameter L1_LINE_SIZE_P        = 64,
    parameter L1D_NUM_REQS_P        = 1, // FIXME
    parameter L1D_NUM_BANKS_P       = `XM_MIN(L1D_NUM_REQS_P, 16),
    parameter L1_NUM_MEM_PORTS_P    = `XM_MIN(L1D_NUM_BANKS_P, `PLATFORM_MEMORY_BANKS),
    parameter L2_NUM_REQS_P	        = NUM_SOCKETS_P * L1_NUM_MEM_PORTS_P,
    ////////////////////////////////////////////////////////////////////////////////
    // L2 Cache configuration
    ////////////////////////////////////////////////////////////////////////////////
    parameter L2_LINE_SIZE_P        = 64,
    // Cache Size
    parameter L2_CACHE_SIZE_P       = 1048576,
    // Number of Banks
    parameter L2_NUM_BANKS_P        = `XM_MIN(L2_NUM_REQS_P, 16),
    // Core Response Queue Size
    parameter L2_CRSQ_SIZE_P        = 2,
    // Miss Handling Register Size
    parameter L2_MSHR_SIZE_P        = 16,
    // Memory Request Queue Size
    parameter L2_MREQ_SIZE_P        = 4,
    // Memory Response Queue Size
    parameter L2_MRSQ_SIZE_P        = 4,
    // Number of Associative Ways
    parameter L2_NUM_WAYS_P         = 8,
    // Enable Cache Writeback
    parameter L2_HAS_WRITEBACK_P    = 0,
    // Enable Cache Dirty bytes
    parameter L2_HAS_DIRTY_BYTES_P  = L2_HAS_WRITEBACK_P,
    // Replacement Policy
    parameter L2_REPL_POLICY_P      = 1,
    // Number of Memory Ports
    parameter L2_NUM_MEM_PORTS_P    = `XM_MIN(L2_NUM_BANKS_P, `PLATFORM_MEMORY_BANKS),
    ////////////////////////////////////////////////////////////////////////////////
    // L1D Cache configuration
    ////////////////////////////////////////////////////////////////////////////////
    // Number of Cache Units
    parameter NUM_L1I_CACHES_P      = `XM_UP(SOCKET_SIZE_P / 4),
    // Cache Size
    parameter L1I_SIZE_P            = 16384,
    // Core Response Queue Size
    parameter L1I_CRSQ_SIZE_P       = 2,
    // Miss Handling Register Size
    parameter L1I_MSHR_SIZE_P       = 16,
    // Memory Request Queue Size
    parameter L1I_MREQ_SIZE_P       = 4,
    // Memory Response Queue Size
    parameter L1I_MRSQ_SIZE_P       = 0,
    // Number of Associative Ways
    parameter L1I_NUM_WAYS_P        = 4,
    // Replacement Policy
    parameter L1I_REPL_POLICY_P     = 1,
    //
    parameter L1I_NUM_MEM_PORTS_P   = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // L1D Cache configuration
    ////////////////////////////////////////////////////////////////////////////////
    // Number of Cache Units
    parameter NUM_L1D_CACHES_P      = `XM_UP(SOCKET_SIZE_P / 4),
    // Cache Size
    parameter L1D_SIZE_P            = 16384,
    // Core Response Queue Size
    parameter L1D_CRSQ_SIZE_P       = 2,
    // Miss Handling Register Size
    parameter L1D_MSHR_SIZE_P       = 16,
    // Memory Request Queue Size
    parameter L1D_MREQ_SIZE_P       = 4,
    // Memory Response Queue Size
    parameter L1D_MRSQ_SIZE_P       = 4,
    // Number of Associative Ways
    parameter L1D_NUM_WAYS_P        = 4,
    // Enable Cache Writeback
    parameter L1D_HAS_WRITEBACK_P   = 0,
    // Enable Cache Dirty bytes
    parameter L1D_HAS_DIRTY_BYTES_P = L1D_HAS_WRITEBACK_P,
    // Replacement Policy
    parameter L1D_REPL_POLICY_P     = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_LP          = `XM_CLOG2(NUM_THREADS_P),
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CCLUSTER_CACHE_LOCALPARAMS
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  wire                 clk_i,
    input  wire                 rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    xrv_cache_if.master         mem_bus_if [L2_NUM_MEM_PORTS_P]
);

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (L1_LINE_SIZE_P),
        .TAG_WIDTH_P        (L1_MEM_ARB_TAG_WIDTH_LP)
    ) per_socket_mem_bus_if[NUM_SOCKETS_P * L1_NUM_MEM_PORTS_P]();

    `RESET_RELAY (l2_rst_i, rst_i);

    xrv_cache_wrap #(
        .INSTANCE_ID        (`SFORMATF(("%s-l2cache", INSTANCE_ID))),
        .XLEN_P             (XLEN_P),
        .CACHE_SIZE_P       (L2_CACHE_SIZE_P),
        .LINE_SIZE_P        (L2_LINE_SIZE_P),
        .NUM_BANKS_P        (L2_NUM_BANKS_P),
        .NUM_WAYS_P         (L2_NUM_WAYS_P),
        .WORD_SIZE_P        (L2_WORD_SIZE_LP),
        .NUM_REQS_P         (L2_NUM_REQS_P),
        .NUM_MEM_PORTS_P    (L2_NUM_MEM_PORTS_P),
        .CRSQ_SIZE_P        (L2_CRSQ_SIZE_P),
        .MSHR_SIZE_P        (L2_MSHR_SIZE_P),
        .MRSQ_SIZE_P        (L2_MRSQ_SIZE_P),
        .MREQ_SIZE_P        (L2_HAS_WRITEBACK_P ? L2_MSHR_SIZE_P : L2_MREQ_SIZE_P),
        .TAG_WIDTH_P        (L2_TAG_WIDTH_LP),
        .IS_WRITEABLE_P     (1),
        .HAS_WRITEBACK_P    (L2_HAS_WRITEBACK_P),
        .HAS_DIRTY_BYTES_P  (L2_HAS_DIRTY_BYTES_P),
        .REPL_POLICY        (L2_REPL_POLICY_P),
        .UUID_WIDTH_P       (UUID_WIDTH_P),
        .FLAGS_WIDTH_P      (`MEM_REQ_FLAGS_WIDTH),
        .CORE_OUT_BUF       (3),
        .MEM_OUT_BUF        (3),
        .NC_ENABLE          (1),
        .PASSTHRU_P         (0)
    ) l2cache (
        .clk_i              (clk_i),
        .rst_i              (l2_rst_i),
    `ifdef PERF_ENABLE
        .cache_perf         (mem_perf_tmp_if.l2cache),
    `endif
        .core_bus_if        (per_socket_mem_bus_if),
        .mem_bus_if         (mem_bus_if)
    );

    ///////////////////////////////////////////////////////////////////////////

    wire [NUM_SOCKETS_P-1:0] per_socket_busy;

    // Generate all sockets
    for (genvar socket_id = 0; socket_id < NUM_SOCKETS_P; ++socket_id) begin : g_sockets

        `RESET_RELAY (socket_rst_i, rst_i);

        xrv_cores_socket #(
            .SOCKET_ID                  ((CLUSTER_ID * NUM_SOCKETS_P) + socket_id),
            .INSTANCE_ID                (`SFORMATF(("%s-socket%0d", INSTANCE_ID, socket_id))),
            ///////////////////////////////////////////////////////////////////////////////
            // Core configuration
            ////////////////////////////////////////////////////////////////////////////////
            .NUM_THREADS_P              (NUM_THREADS_P),
            .XLEN_P                     (XLEN_P),
            .MEM_ADDR_WIDTH_P           (MEM_ADDR_WIDTH_P),
            ////////////////////////////////////////////////////////////////////////////////
            // Socket configuration
            ////////////////////////////////////////////////////////////////////////////////
            .SOCKET_SIZE_P              (SOCKET_SIZE_P),
            ////////////////////////////////////////////////////////////////////////////////
            // L1D Cache configuration
            ////////////////////////////////////////////////////////////////////////////////
            .NUM_L1I_CACHES_P           (NUM_L1I_CACHES_P),
            .L1I_SIZE_P                 (L1I_SIZE_P),
            .L1I_CRSQ_SIZE_P            (L1I_CRSQ_SIZE_P),
            .L1I_MSHR_SIZE_P            (L1I_MSHR_SIZE_P),
            .L1I_MREQ_SIZE_P            (L1I_MREQ_SIZE_P),
            .L1I_MRSQ_SIZE_P            (L1I_MRSQ_SIZE_P),
            .L1I_NUM_WAYS_P             (L1I_NUM_WAYS_P),
            .L1I_REPL_POLICY_P          (L1I_REPL_POLICY_P),
            .L1I_NUM_MEM_PORTS_P        (L1I_NUM_MEM_PORTS_P),
            ////////////////////////////////////////////////////////////////////////////////
            // L1D Cache configuration
            ////////////////////////////////////////////////////////////////////////////////
            .NUM_L1D_CACHES_P           (NUM_L1D_CACHES_P),
            .L1D_SIZE_P                 (L1D_SIZE_P),
            .L1D_NUM_BANKS_P            (L1D_NUM_BANKS_P),
            .L1D_CRSQ_SIZE_P            (L1D_CRSQ_SIZE_P),
            .L1D_MSHR_SIZE_P            (L1D_MSHR_SIZE_P),
            .L1D_MREQ_SIZE_P            (L1D_MREQ_SIZE_P),
            .L1D_MRSQ_SIZE_P            (L1D_MRSQ_SIZE_P),
            .L1D_NUM_WAYS_P             (L1D_NUM_WAYS_P),
            .L1D_HAS_WRITEBACK_P        (L1D_HAS_WRITEBACK_P),
            .L1D_HAS_DIRTY_BYTES_P      (L1D_HAS_DIRTY_BYTES_P),
            .L1D_REPL_POLICY_P          (L1D_REPL_POLICY_P)
            ////////////////////////////////////////////////////////////////////////////////
        ) socket_i (
            .clk_i          (clk_i),
            .rst_i          (socket_rst_i),
        `ifdef PERF_ENABLE
            .mem_perf_if    (mem_perf_tmp_if),
        `endif
            .mem_bus_if     (per_socket_mem_bus_if[socket_id * L1_NUM_MEM_PORTS_P +: L1_NUM_MEM_PORTS_P])
        );
    end

endmodule
