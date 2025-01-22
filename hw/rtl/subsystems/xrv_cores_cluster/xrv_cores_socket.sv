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


module xrv_cores_socket #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter SOCKET_ID             = 0,
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter SOCKET_SIZE_P         = 4,
    parameter L1_LINE_SIZE_P        = 64,
    ////////////////////////////////////////////////////////////////////////////////
    // Core configuration
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = 32,
    parameter NUM_THREADS_P         = 8,
    parameter MEM_ADDR_WIDTH_P      = (XLEN_P == 32 ? 32 : 48),
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P          = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // Word size in bytes
    parameter L1D_WORD_SIZE_LP	    = XLEN_P / 8,
    parameter L1D_ADDR_WIDTH_LP	    = (MEM_ADDR_WIDTH_P - `XM_CLOG2(L1D_WORD_SIZE_LP)),
    // Block size in bytes
    parameter L1D_LINE_SIZE_LP 	    = L1_LINE_SIZE_P,
    // Input request size (using coalesced memory blocks)
    parameter L1D_CHANNELS	        = `XM_UP(LSU_WORD_SIZE_LP / L1D_WORD_SIZE_LP),
    parameter L1D_NUM_REQS_P	    = L1D_CHANNELS, // FIXME;
    parameter L1D_NUM_BANKS_P       = `XM_MIN(L1D_NUM_REQS_P, 16),
    parameter L1_NUM_MEM_PORTS_P    = `XM_MIN(L1D_NUM_BANKS_P, `PLATFORM_MEMORY_BANKS),
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
    parameter TID_WIDTH_LP          = `XM_CLOG2(NUM_THREADS_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input wire              clk_i,
    input wire              rst_i,
`ifdef PERF_ENABLE
    xrv_mem_perf_if.slave    mem_perf_if,
`endif
    ////////////////////////////////////////////////////////////////////////////////
    xrv_cache_if.master    mem_bus_if [L1_NUM_MEM_PORTS_P]
);
    ////////////////////////////////////////////////////////////////////////////////
    // LSU parameters
    ////////////////////////////////////////////////////////////////////////////////
    localparam LSU_WORD_SIZE_LP         = XLEN_P / 8;
    localparam LSU_ADDR_WIDTH_LP	    = (MEM_ADDR_WIDTH_P - `XM_CLOG2(LSU_WORD_SIZE_LP));
    localparam LSU_TAG_ID_BITS          = (`XM_CLOG2(8)); // FIXME ITAG_WIDTH_P
    localparam LSU_TAG_WIDTH            = (UUID_WIDTH_P + LSU_TAG_ID_BITS);
    localparam LSU_NUM_REQS	            = 1; // `NUM_LSU_BLOCKS;
    ////////////////////////////////////////////////////////////////////////////////
    // L1I parameters
    ////////////////////////////////////////////////////////////////////////////////
    localparam L1I_WORD_SIZE_LP	        = 4;
    localparam L1I_ADDR_WIDTH_LP	    = (MEM_ADDR_WIDTH_P - `XM_CLOG2(L1I_WORD_SIZE_LP));
    // Block size in bytes
    localparam L1I_LINE_SIZE_LP	        = L1_LINE_SIZE_P;
    // Core request tag Id bits
    localparam L1I_TAG_ID_BITS_LP	    = TID_WIDTH_LP;
    // Core request tag bits
    localparam L1I_TAG_WIDTH_LP	        = (UUID_WIDTH_P + L1I_TAG_ID_BITS_LP);
    // Memory request data bits
    localparam L1I_MEM_DATA_WIDTH_LP    = (L1I_LINE_SIZE_LP * 8);
    // Memory request tag bits
    localparam L1I_MEM_TAG_WIDTH_LP     = `CACHE_CLUSTER_MEM_TAG_WIDTH(L1I_MSHR_SIZE_P, 1, 1, NUM_L1I_CACHES_P, UUID_WIDTH_P);
    ////////////////////////////////////////////////////////////////////////////////
    // L1D parameters
    ////////////////////////////////////////////////////////////////////////////////
    // Core request tag Id bits
    localparam L1D_TAG_ID_BITS_LP       = `XM_CLOG2(8);
    // Core request tag bits
    localparam L1D_TAG_WIDTH_LP	        = (UUID_WIDTH_P + L1D_TAG_ID_BITS_LP);
    // Memory request data bits
    localparam L1D_MEM_DATA_WIDTH_LP    = (L1D_LINE_SIZE_LP * 8);
    // Memory request tag bits
    localparam L1D_MEM_TAG_WIDTH_LP     = `CACHE_CLUSTER_NC_MEM_TAG_WIDTH(L1D_MSHR_SIZE_P, L1D_NUM_BANKS_P, L1D_NUM_REQS_P, L1_NUM_MEM_PORTS_P, L1D_LINE_SIZE_LP, L1D_WORD_SIZE_LP, L1D_TAG_WIDTH_LP, SOCKET_SIZE_P, NUM_L1D_CACHES_P, UUID_WIDTH_P);
    ////////////////////////////////////////////////////////////////////////////////
    // L1 parameters
    ////////////////////////////////////////////////////////////////////////////////
    // arbitrate between icache and dcache
    localparam L1_MEM_TAG_WIDTH_LP      = `XM_MAX(L1I_MEM_TAG_WIDTH_LP, L1D_MEM_TAG_WIDTH_LP);
    localparam L1_MEM_ARB_TAG_WIDTH_LP  = (L1_MEM_TAG_WIDTH_LP + `XM_CLOG2(2));
    ////////////////////////////////////////////////////////////////////////////////

`ifdef PERF_ENABLE
    xrv_mem_perf_if mem_perf_tmp_if();
    assign mem_perf_tmp_if.l2cache = mem_perf_if.l2cache;
    assign mem_perf_tmp_if.l3cache = mem_perf_if.l3cache;
    assign mem_perf_tmp_if.lmem = 'x;
    assign mem_perf_tmp_if.mem = mem_perf_if.mem;
`endif

    ///////////////////////////////////////////////////////////////////////////

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (L1I_WORD_SIZE_LP),
        .TAG_WIDTH_P        (L1I_TAG_WIDTH_LP)
    ) per_core_icache_bus_if[SOCKET_SIZE_P]();

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (L1I_LINE_SIZE_LP),
        .TAG_WIDTH_P        (L1I_MEM_TAG_WIDTH_LP)
    ) icache_mem_bus_if[1]();

    `RESET_RELAY (icache_rst_i, rst_i);

    xrv_cache_cluster #(
        .INSTANCE_ID        (`SFORMATF(("%s-icache", INSTANCE_ID))),
        .XLEN_P             (XLEN_P),
        .NUM_UNITS          (NUM_L1I_CACHES_P),
        .NUM_INPUTS         (SOCKET_SIZE_P),
        .TAG_SEL_IDX        (0),
        .CACHE_SIZE_P       (L1I_SIZE_P),
        .LINE_SIZE_P        (L1I_LINE_SIZE_LP),
        .NUM_BANKS_P        (1),
        .NUM_WAYS_P         (L1I_NUM_WAYS_P),
        .WORD_SIZE_P        (L1I_WORD_SIZE_LP),
        .NUM_REQS_P         (1),
        .NUM_MEM_PORTS_P    (1),
        .CRSQ_SIZE_P        (L1I_CRSQ_SIZE_P),
        .MSHR_SIZE_P        (L1I_MSHR_SIZE_P),
        .MRSQ_SIZE_P        (L1I_MRSQ_SIZE_P),
        .MREQ_SIZE_P        (L1I_MREQ_SIZE_P),
        .TAG_WIDTH_P        (L1I_TAG_WIDTH_LP),
        .FLAGS_WIDTH_P      (0),
        .UUID_WIDTH_P       (UUID_WIDTH_P),
        .IS_WRITEABLE_P     (0),
        .REPL_POLICY        (L1I_REPL_POLICY_P),
        .NC_ENABLE          (0),
        .CORE_OUT_BUF       (3),
        .MEM_OUT_BUF        (2)
    ) icache (
    `ifdef PERF_ENABLE
        .cache_perf         (mem_perf_tmp_if.icache),
    `endif
        .clk_i              (clk_i),
        .rst_i              (icache_rst_i),
        .core_bus_if        (per_core_icache_bus_if),
        .mem_bus_if         (icache_mem_bus_if)
    );

    ///////////////////////////////////////////////////////////////////////////

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (L1D_WORD_SIZE_LP),
        .TAG_WIDTH_P        (L1D_TAG_WIDTH_LP)
    ) per_core_dcache_bus_if[SOCKET_SIZE_P * L1D_NUM_REQS_P]();

    xrv_cache_if #(
        .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
        .DATA_SIZE_P        (L1D_LINE_SIZE_LP),
        .TAG_WIDTH_P        (L1D_MEM_TAG_WIDTH_LP)
    ) dcache_mem_bus_if[L1_NUM_MEM_PORTS_P]();

    `RESET_RELAY (dcache_rst_i, rst_i);

    xrv_cache_cluster #(
        .INSTANCE_ID            (`SFORMATF(("%s-dcache", INSTANCE_ID))),
        .NUM_UNITS              (NUM_L1D_CACHES_P),
        .NUM_INPUTS             (SOCKET_SIZE_P),
        .TAG_SEL_IDX            (0),
        .CACHE_SIZE_P           (L1D_SIZE_P),
        .LINE_SIZE_P            (L1D_LINE_SIZE_LP),
        .NUM_BANKS_P            (L1D_NUM_BANKS_P),
        .NUM_WAYS_P             (L1D_NUM_WAYS_P),
        .WORD_SIZE_P            (L1D_WORD_SIZE_LP),
        .NUM_REQS_P             (L1D_NUM_REQS_P),
        .NUM_MEM_PORTS_P        (L1_NUM_MEM_PORTS_P),
        .CRSQ_SIZE_P            (L1D_CRSQ_SIZE_P),
        .MSHR_SIZE_P            (L1D_MSHR_SIZE_P),
        .MRSQ_SIZE_P            (L1D_MRSQ_SIZE_P),
        .MREQ_SIZE_P            (L1D_HAS_WRITEBACK_P ? L1D_MSHR_SIZE_P : L1D_MREQ_SIZE_P),
        .TAG_WIDTH_P            (L1D_TAG_WIDTH_LP),
        .UUID_WIDTH_P           (UUID_WIDTH_P),
        .FLAGS_WIDTH_P          (`MEM_REQ_FLAGS_WIDTH),
        .IS_WRITEABLE_P         (1),
        .HAS_WRITEBACK_P        (L1D_HAS_WRITEBACK_P),
        .HAS_DIRTY_BYTES_P      (L1D_HAS_DIRTY_BYTES_P),
        .REPL_POLICY            (L1D_REPL_POLICY_P),
        .NC_ENABLE              (1),
        .CORE_OUT_BUF           (3),
        .MEM_OUT_BUF            (2)
    ) dcache (
    `ifdef PERF_ENABLE
        .cache_perf             (mem_perf_tmp_if.dcache),
    `endif
        .clk_i                  (clk_i),
        .rst_i                  (dcache_rst_i),
        .core_bus_if            (per_core_dcache_bus_if),
        .mem_bus_if             (dcache_mem_bus_if)
    );

    ///////////////////////////////////////////////////////////////////////////
    for (genvar i = 0; i < L1_NUM_MEM_PORTS_P; ++i) begin : g_mem_bus_if
        if (i == 0) begin : g_i0
            xrv_cache_if #(
                .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
                .DATA_SIZE_P        (L1_LINE_SIZE_P),
                .TAG_WIDTH_P        (L1_MEM_TAG_WIDTH_LP)
            ) l1_mem_bus_if[2]();

            xrv_cache_if #(
                .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
                .DATA_SIZE_P        (L1_LINE_SIZE_P),
                .TAG_WIDTH_P        (L1_MEM_ARB_TAG_WIDTH_LP)
            ) l1_mem_arb_bus_if[1]();

            `ASSIGN_XRV_CACHE_IF_EX (l1_mem_bus_if[0], icache_mem_bus_if[0], L1_MEM_TAG_WIDTH_LP, L1I_MEM_TAG_WIDTH_LP, UUID_WIDTH_P);
            `ASSIGN_XRV_CACHE_IF_EX (l1_mem_bus_if[1], dcache_mem_bus_if[0], L1_MEM_TAG_WIDTH_LP, L1D_MEM_TAG_WIDTH_LP, UUID_WIDTH_P);

            xrv_mem_arb #(
                .NUM_INPUTS_P   (2),
                .DATA_SIZE_P    (L1_LINE_SIZE_P),
                .TAG_WIDTH_P    (L1_MEM_TAG_WIDTH_LP),
                .TAG_SEL_IDX    (0),
                .ARBITER_TYPE_P ("P"), // prioritize the icache
                .REQ_OUT_BUF    (3),
                .RSP_OUT_BUF    (3)
            ) mem_arb (
                .clk_i          (clk_i),
                .rst_i          (rst_i),
                .bus_in_if      (l1_mem_bus_if),
                .bus_out_if     (l1_mem_arb_bus_if)
            );

            `ASSIGN_XRV_CACHE_IF (mem_bus_if[0], l1_mem_arb_bus_if[0]);
        end else begin : g_i
            xrv_cache_if #(
                .MEM_ADDR_WIDTH_P   (MEM_ADDR_WIDTH_P),
                .DATA_SIZE_P        (L1_LINE_SIZE_P),
                .TAG_WIDTH_P        (L1_MEM_ARB_TAG_WIDTH_LP)
            ) l1_mem_arb_bus_if();

            `ASSIGN_XRV_CACHE_IF_EX (l1_mem_arb_bus_if, dcache_mem_bus_if[i], L1_MEM_ARB_TAG_WIDTH_LP, L1D_MEM_TAG_WIDTH_LP, UUID_WIDTH_P);
            `ASSIGN_XRV_CACHE_IF (mem_bus_if[i], l1_mem_arb_bus_if);
        end
    end
    ///////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////
    // Generate all cores
    ///////////////////////////////////////////////////////////////////////////
    for (genvar core_id = 0; core_id < SOCKET_SIZE_P; ++core_id) begin : g_cores

        `RESET_RELAY (core_rst_i, rst_i);

        mrv1_core #(
            .CORE_ID                ((SOCKET_ID * SOCKET_SIZE_P) + core_id),
            .INSTANCE_ID            (`SFORMATF(("%s-core%0d", INSTANCE_ID, core_id))),
            ///////////////////////////////////////////////////////////////////////////
            .XLEN_P                 (XLEN_P),
            .NUM_THREADS_P          (NUM_THREADS_P)
            ///////////////////////////////////////////////////////////////////////////
        ) core (
            .clk_i                  (clk_i),
            .rst_i                  (core_rst_i),
            ///////////////////////////////////////////////////////////////////////////
            .imem_req_vld_o         (per_core_icache_bus_if[core_id].req_vld),
            .imem_req_rdy_i         (per_core_icache_bus_if[core_id].req_rdy),
            .imem_req_tag_o         (per_core_icache_bus_if[core_id].req_data.tag),
            .imem_req_addr_o        (per_core_icache_bus_if[core_id].req_data.addr),
            .imem_resp_vld_i        (per_core_icache_bus_if[core_id].resp_vld),
            .imem_resp_tag_i        (per_core_icache_bus_if[core_id].resp_data.tag),
            .imem_resp_data_i       (per_core_icache_bus_if[core_id].resp_data.data),
            ////////////////////////////////////////////////////////////////////////////////
            .dmem_req_vld_o         (per_core_dcache_bus_if[core_id].req_vld),
            .dmem_req_rdy_i         (per_core_dcache_bus_if[core_id].req_rdy),
            .dmem_resp_err_i        ('0),
            .dmem_req_addr_o        (per_core_dcache_bus_if[core_id].req_data.addr),
            .dmem_req_w_en_o        (per_core_dcache_bus_if[core_id].req_data.rw),
            .dmem_req_w_be_o        (per_core_dcache_bus_if[core_id].req_data.be),
            .dmem_req_tag_o         (per_core_dcache_bus_if[core_id].req_data.tag),
            .dmem_req_w_data_o      (per_core_dcache_bus_if[core_id].req_data.data),
            .dmem_resp_vld_i        (per_core_dcache_bus_if[core_id].resp_vld),
            .dmem_resp_tag_i        (per_core_dcache_bus_if[core_id].resp_data.tag),
            .dmem_resp_r_data_i     (per_core_dcache_bus_if[core_id].resp_data.data),
            ////////////////////////////////////////////////////////////////////////////////
            .fetch_en_i             (1'b1),
            .simt_en_i              (1'b0)
        );
    end

endmodule
