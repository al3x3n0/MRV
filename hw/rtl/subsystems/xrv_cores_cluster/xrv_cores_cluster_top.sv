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


module xrv_cores_cluster_top #(
    ///////////////////////////////////////////////////////////////////////////////
    // Core configuration
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_THREADS_P         = 8,
    parameter XLEN_P                = 32,
    parameter MEM_ADDR_WIDTH_P      = (XLEN_P == 32 ? 32 : 48),
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P          = 0,
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
    //
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
    `XRV_CCLUSTER_CACHE_LOCALPARAMS,
    ////////////////////////////////////////////////////////////////////////////////
    // Cluster configuration
    ////////////////////////////////////////////////////////////////////////////////
    parameter CLUSTER_NUM_MEM_PORTS_P = L2_NUM_MEM_PORTS_P,
    parameter CLUSTER_MEM_TAG_WIDTH_P = `CACHE_NC_MEM_TAG_WIDTH(L2_MSHR_SIZE_P, L2_NUM_BANKS_P, L2_NUM_REQS_P, L2_NUM_MEM_PORTS_P, L2_LINE_SIZE_P, L2_WORD_SIZE_LP, L2_TAG_WIDTH_LP, UUID_WIDTH_P),
    parameter CLUSTER_MEM_ADDR_WIDTH_P = (MEM_ADDR_WIDTH_P - `XM_CLOG2(L2_LINE_SIZE_P)),
    parameter CLUSTER_MEM_DATA_WIDTH_P = (L2_LINE_SIZE_P * 8),
    parameter CLUSTER_MEM_BYTEEN_WIDTH_P = L2_LINE_SIZE_P
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  wire                             clk_i,
    input  wire                             rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // Memory request
    ////////////////////////////////////////////////////////////////////////////////
    output wire                                     mem_req_vld [CLUSTER_NUM_MEM_PORTS_P],
    output wire                                     mem_req_rw [CLUSTER_NUM_MEM_PORTS_P],
    output wire [CLUSTER_MEM_BYTEEN_WIDTH_P-1:0]    mem_req_be [CLUSTER_NUM_MEM_PORTS_P],
    output wire [CLUSTER_MEM_ADDR_WIDTH_P-1:0]      mem_req_addr [CLUSTER_NUM_MEM_PORTS_P],
    output wire [CLUSTER_MEM_DATA_WIDTH_P-1:0]      mem_req_data [CLUSTER_NUM_MEM_PORTS_P],
    output wire [CLUSTER_MEM_TAG_WIDTH_P-1:0]       mem_req_tag [CLUSTER_NUM_MEM_PORTS_P],
    input  wire                                     mem_req_rdy [CLUSTER_NUM_MEM_PORTS_P],
    ////////////////////////////////////////////////////////////////////////////////
    // Memory response
    ////////////////////////////////////////////////////////////////////////////////
    input wire                                      mem_resp_vld [CLUSTER_NUM_MEM_PORTS_P],
    input wire [CLUSTER_MEM_DATA_WIDTH_P-1:0]       mem_resp_data [CLUSTER_NUM_MEM_PORTS_P],
    input wire [CLUSTER_MEM_TAG_WIDTH_P-1:0]        mem_resp_tag [CLUSTER_NUM_MEM_PORTS_P],
    output wire                                     mem_resp_rdy [CLUSTER_NUM_MEM_PORTS_P]
);

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (L2_LINE_SIZE_P),
        .TAG_WIDTH_P        (L2_MEM_TAG_WIDTH_LP)
    ) mem_bus_if[L2_NUM_MEM_PORTS_P]();

    for (genvar i = 0; i < L2_NUM_MEM_PORTS_P; ++i) begin : g_mem_bus_if
        assign mem_req_vld[i]       = mem_bus_if[i].req_vld;
        assign mem_req_rw[i]        = mem_bus_if[i].req_data.rw;
        assign mem_req_be[i]        = mem_bus_if[i].req_data.be;
        assign mem_req_addr[i]      = mem_bus_if[i].req_data.addr;
        assign mem_req_data[i]      = mem_bus_if[i].req_data.data;
        assign mem_req_tag[i]       = mem_bus_if[i].req_data.tag;
        `XM_UNUSED_VAR (mem_bus_if[i].req_data.flags)
        assign mem_bus_if[i].req_rdy = mem_req_rdy[i];

        assign mem_bus_if[i].resp_vld        = mem_resp_vld[i];
        assign mem_bus_if[i].resp_data.data  = mem_resp_data[i];
        assign mem_bus_if[i].resp_data.tag   = mem_resp_tag[i];
        assign mem_resp_rdy[i] = mem_bus_if[i].resp_rdy;
    end

    `RESET_RELAY (cluster_rst_i, rst_i);

    xrv_cores_cluster #(
        .CLUSTER_ID                 (0),
        .INSTANCE_ID                (`SFORMATF(("cluster"))),
        ///////////////////////////////////////////////////////////////////////////////
        // Core configuration
        ////////////////////////////////////////////////////////////////////////////////
        .NUM_THREADS_P              (NUM_THREADS_P),
        .XLEN_P                     (XLEN_P),
        .MEM_ADDR_WIDTH_P           (MEM_ADDR_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        .UUID_WIDTH_P               (UUID_WIDTH_P),
        ////////////////////////////////////////////////////////////////////////////////
        // Socket configuration
        ////////////////////////////////////////////////////////////////////////////////
        .NUM_SOCKETS_P              (NUM_SOCKETS_P),
        .SOCKET_SIZE_P              (SOCKET_SIZE_P),
        ////////////////////////////////////////////////////////////////////////////////
        .L2_LINE_SIZE_P             (L2_LINE_SIZE_P),
        .L2_CACHE_SIZE_P            (L2_CACHE_SIZE_P),
        .L2_NUM_BANKS_P             (L2_NUM_BANKS_P),
        .L2_CRSQ_SIZE_P             (L2_CRSQ_SIZE_P),
        .L2_MSHR_SIZE_P             (L2_MSHR_SIZE_P),
        .L2_MREQ_SIZE_P             (L2_MREQ_SIZE_P),
        .L2_MRSQ_SIZE_P             (L2_MRSQ_SIZE_P),
        .L2_NUM_WAYS_P              (L2_NUM_WAYS_P),
        .L2_HAS_WRITEBACK_P         (L2_HAS_WRITEBACK_P),
        .L2_HAS_DIRTY_BYTES_P       (L2_HAS_DIRTY_BYTES_P),
        .L2_REPL_POLICY_P           (L2_REPL_POLICY_P),
        .L2_NUM_MEM_PORTS_P         (L2_NUM_MEM_PORTS_P),
        ////////////////////////////////////////////////////////////////////////////////
        // L1D Cache configuration
        ////////////////////////////////////////////////////////////////////////////////
        .NUM_L1I_CACHES_P          (NUM_L1I_CACHES_P),
        .L1I_SIZE_P                (L1I_SIZE_P),
        .L1I_CRSQ_SIZE_P           (L1I_CRSQ_SIZE_P),
        .L1I_MSHR_SIZE_P           (L1I_MSHR_SIZE_P),
        .L1I_MREQ_SIZE_P           (L1I_MREQ_SIZE_P),
        .L1I_MRSQ_SIZE_P           (L1I_MRSQ_SIZE_P),
        .L1I_NUM_WAYS_P            (L1I_NUM_WAYS_P),
        .L1I_REPL_POLICY_P         (L1I_REPL_POLICY_P),
        .L1I_NUM_MEM_PORTS_P       (L1I_NUM_MEM_PORTS_P),
        ////////////////////////////////////////////////////////////////////////////////
        // L1D Cache configuration
        ////////////////////////////////////////////////////////////////////////////////
        .NUM_L1D_CACHES_P          (NUM_L1D_CACHES_P),
        .L1D_SIZE_P                (L1D_SIZE_P),
        .L1D_NUM_BANKS_P           (L1D_NUM_BANKS_P),
        .L1D_CRSQ_SIZE_P           (L1D_CRSQ_SIZE_P),
        .L1D_MSHR_SIZE_P           (L1D_MSHR_SIZE_P),
        .L1D_MREQ_SIZE_P           (L1D_MREQ_SIZE_P),
        .L1D_MRSQ_SIZE_P           (L1D_MRSQ_SIZE_P),
        .L1D_NUM_WAYS_P            (L1D_NUM_WAYS_P),
        .L1D_HAS_WRITEBACK_P       (L1D_HAS_WRITEBACK_P),
        .L1D_HAS_DIRTY_BYTES_P     (L1D_HAS_DIRTY_BYTES_P),
        .L1D_REPL_POLICY_P         (L1D_REPL_POLICY_P)
        ////////////////////////////////////////////////////////////////////////////////
    ) cluster (
        .clk_i              (clk_i),
        .rst_i              (cluster_rst_i),
        .mem_bus_if         (mem_bus_if)
    );

endmodule
