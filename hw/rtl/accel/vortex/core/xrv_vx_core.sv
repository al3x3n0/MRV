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

`include "xrv_vx_define.vh"

`ifdef EXT_F_ENABLE
`include "xrv_vx_fpu_define.vh"
`endif

module xrv_vx_core import xrv_vx_gpu_pkg::*; #(
    parameter CORE_ID               = 0,
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = 64,
    parameter PC_WIDTH_P            = XLEN_P,
    parameter NUM_WARPS_P           = 32,
    parameter NUM_THREADS_P         = 32,
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P         = 4
    ////////////////////////////////////////////////////////////////////////////////
) (
    `SCOPE_IO_DECL

    ////////////////////////////////////////////////////////////////////////////////
    // Clock
    input wire                  clk_i,
    input wire                  rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input wire                  vx_mode_en_i,
    ////////////////////////////////////////////////////////////////////////////////
`ifdef PERF_ENABLE
    xrv_vx_mem_perf_if.slave    mem_perf_if,
`endif

    xrv_vx_dcr_bus_if.slave     dcr_bus_if,

    xrv_cache_if.master         dcache_bus_if [DCACHE_NUM_REQS],
    xrv_cache_if.master         icache_bus_if,

`ifdef GBAR_ENABLE
    xrv_vx_gbar_bus_if.master   gbar_bus_if,
`endif

    // Status
    output wire             busy
);
    xrv_vx_schedule_if #(
        .PC_WIDTH_P     (PC_WIDTH_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P)
    ) schedule_if();

    xrv_vx_fetch_if         fetch_if();
    xrv_vx_decode_if        decode_if();
    xrv_vx_sched_csr_if     sched_csr_if();
    xrv_vx_decode_sched_if  decode_sched_if();
    xrv_vx_commit_sched_if  commit_sched_if();
    xrv_vx_commit_csr_if    commit_csr_if();
    xrv_vx_branch_ctl_if    branch_ctl_if[NUM_ALU_BLOCKS_P]();
    xrv_vx_warp_ctl_if      warp_ctl_if();

    xrv_vx_dispatch_if      dispatch_if[NUM_EX_UNITS_P * ISSUE_WIDTH_P]();
    xrv_vx_commit_if        commit_if[NUM_EX_UNITS_P * ISSUE_WIDTH_P]();
    xrv_vx_writeback_if     writeback_if[ISSUE_WIDTH_P]();

    xrv_vx_lsu_mem_if #(
        .NUM_LANES (`NUM_LSU_LANES),
        .DATA_SIZE (LSU_WORD_SIZE),
        .TAG_WIDTH (LSU_TAG_WIDTH)
    ) lsu_mem_if[NUM_LSU_BLOCKS_P]();

`ifdef PERF_ENABLE
    xrv_vx_mem_perf_if mem_perf_tmp_if();
    xrv_vx_pipeline_perf_if pipeline_perf_if();

    assign mem_perf_tmp_if.icache  = mem_perf_if.icache;
    assign mem_perf_tmp_if.dcache  = mem_perf_if.dcache;
    assign mem_perf_tmp_if.l2cache = mem_perf_if.l2cache;
    assign mem_perf_tmp_if.l3cache = mem_perf_if.l3cache;
    assign mem_perf_tmp_if.mem     = mem_perf_if.mem;
`endif

    base_dcrs_t base_dcrs;

    xrv_vx_dcr_data dcr_data (
        .clk_i        (clk_i),
        .rst_i      (rst_i),
        .dcr_bus_if (dcr_bus_if),
        .base_dcrs  (base_dcrs)
    );

    `SCOPE_IO_SWITCH (3);

    xrv_vx_schedule #(
        .INSTANCE_ID    (`SFORMATF(("%s-schedule", INSTANCE_ID))),
        .CORE_ID        (CORE_ID),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .PC_WIDTH_P     (PC_WIDTH_P)
    ) schedule (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

    `ifdef PERF_ENABLE
        .sched_perf     (pipeline_perf_if.sched),
    `endif

        .base_dcrs      (base_dcrs),

        .warp_ctl_if    (warp_ctl_if),
        .branch_ctl_if  (branch_ctl_if),

        .decode_sched_if(decode_sched_if),
        .commit_sched_if(commit_sched_if),

        .schedule_if    (schedule_if),
    `ifdef GBAR_ENABLE
        .gbar_bus_if    (gbar_bus_if),
    `endif
        .sched_csr_if   (sched_csr_if),

        .busy           (busy)
    );

    xrv_vx_fetch #(
        .INSTANCE_ID    (`SFORMATF(("%s-fetch", INSTANCE_ID))),
        ////////////////////////////////////////////////////////////////////////////////
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .PC_WIDTH_P     (PC_WIDTH_P)
    ) fetch (
        `SCOPE_IO_BIND  (0)
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .icache_bus_if  (icache_bus_if),
        .schedule_if    (schedule_if),
        .fetch_if       (fetch_if)
    );

    xrv_vx_decode #(
        .INSTANCE_ID (`SFORMATF(("%s-decode", INSTANCE_ID)))
    ) decode (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .fetch_if           (fetch_if),
        .decode_if          (decode_if),
        .decode_sched_if    (decode_sched_if)
    );

    xrv_vx_issue #(
        .INSTANCE_ID (`SFORMATF(("%s-issue", INSTANCE_ID)))
    ) issue (
        `SCOPE_IO_BIND  (1)

        .clk_i              (clk_i),
        .rst_i              (rst_i),

    `ifdef PERF_ENABLE
        .issue_perf         (pipeline_perf_if.issue),
    `endif

        .decode_if          (decode_if),
        .writeback_if       (writeback_if),
        .dispatch_if        (dispatch_if)
    );

    xrv_vx_execute #(
        .INSTANCE_ID    (`SFORMATF(("%s-execute", INSTANCE_ID))),
        .CORE_ID        (CORE_ID)
    ) execute (
        `SCOPE_IO_BIND  (2)

        .clk_i          (clk_i),
        .rst_i          (rst_i),

        .vx_mode_en_i   (vx_mode_en_i),

    `ifdef PERF_ENABLE
        .mem_perf_if    (mem_perf_tmp_if),
        .pipeline_perf_if(pipeline_perf_if),
    `endif

        .base_dcrs      (base_dcrs),

        .lsu_mem_if     (lsu_mem_if),

        .dispatch_if    (dispatch_if),
        .commit_if      (commit_if),

        .commit_csr_if  (commit_csr_if),
        .sched_csr_if   (sched_csr_if),

        .warp_ctl_if    (warp_ctl_if),
        .branch_ctl_if  (branch_ctl_if)
    );

    xrv_vx_commit #(
        .INSTANCE_ID (`SFORMATF(("%s-commit", INSTANCE_ID))),
        ////////////////////////////////////////////////////////////////////////////////
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .PC_WIDTH_P     (PC_WIDTH_P)
    ) commit (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

        .commit_if      (commit_if),

        .writeback_if   (writeback_if),

        .commit_csr_if  (commit_csr_if),
        .commit_sched_if(commit_sched_if)
    );

    xrv_vx_mem_unit #(
        .INSTANCE_ID (INSTANCE_ID)
    ) mem_unit (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
    `ifdef PERF_ENABLE
        .lmem_perf      (mem_perf_tmp_if.lmem),
    `endif
        .lsu_mem_if     (lsu_mem_if),
        .dcache_bus_if  (dcache_bus_if)
    );

`ifdef PERF_ENABLE

    wire [`XM_CLOG2(LSU_NUM_REQS+1)-1:0] perf_dcache_rd_req_per_cycle;
    wire [`XM_CLOG2(LSU_NUM_REQS+1)-1:0] perf_dcache_wr_req_per_cycle;
    wire [`XM_CLOG2(LSU_NUM_REQS+1)-1:0] perf_dcache_rsp_per_cycle;

    wire [1:0] perf_icache_pending_read_cycle;
    wire [`XM_CLOG2(LSU_NUM_REQS+1)+1-1:0] perf_dcache_pending_read_cycle;

    reg [`PERF_CTR_BITS-1:0] perf_icache_pending_reads;
    reg [`PERF_CTR_BITS-1:0] perf_dcache_pending_reads;

    reg [`PERF_CTR_BITS-1:0] perf_ifetches;
    reg [`PERF_CTR_BITS-1:0] perf_loads;
    reg [`PERF_CTR_BITS-1:0] perf_stores;

    wire perf_icache_req_fire = icache_bus_if.req_valid && icache_bus_if.req_ready;
    wire perf_icache_rsp_fire = icache_bus_if.rsp_valid && icache_bus_if.rsp_ready;

    wire [LSU_NUM_REQS-1:0] perf_dcache_rd_req_fire, perf_dcache_rd_req_fire_r;
    wire [LSU_NUM_REQS-1:0] perf_dcache_wr_req_fire, perf_dcache_wr_req_fire_r;
    wire [LSU_NUM_REQS-1:0] perf_dcache_rsp_fire;

    for (genvar i = 0; i < NUM_LSU_BLOCKS_P; ++i) begin : g_perf_dcache
        for (genvar j = 0; j < `NUM_LSU_LANES; ++j) begin : g_j
            assign perf_dcache_rd_req_fire[i * `NUM_LSU_LANES + j] = lsu_mem_if[i].req_valid && lsu_mem_if[i].req_data.mask[j] && lsu_mem_if[i].req_ready && ~lsu_mem_if[i].req_data.rw;
            assign perf_dcache_wr_req_fire[i * `NUM_LSU_LANES + j] = lsu_mem_if[i].req_valid && lsu_mem_if[i].req_data.mask[j] && lsu_mem_if[i].req_ready && lsu_mem_if[i].req_data.rw;
            assign perf_dcache_rsp_fire[i * `NUM_LSU_LANES + j] = lsu_mem_if[i].rsp_valid && lsu_mem_if[i].rsp_data.mask[j] && lsu_mem_if[i].rsp_ready;
        end
    end

    `BUFFER(perf_dcache_rd_req_fire_r, perf_dcache_rd_req_fire);
    `BUFFER(perf_dcache_wr_req_fire_r, perf_dcache_wr_req_fire);

    `POP_COUNT(perf_dcache_rd_req_per_cycle, perf_dcache_rd_req_fire_r);
    `POP_COUNT(perf_dcache_wr_req_per_cycle, perf_dcache_wr_req_fire_r);
    `POP_COUNT(perf_dcache_rsp_per_cycle, perf_dcache_rsp_fire);

    assign perf_icache_pending_read_cycle = perf_icache_req_fire - perf_icache_rsp_fire;
    assign perf_dcache_pending_read_cycle = perf_dcache_rd_req_per_cycle - perf_dcache_rsp_per_cycle;

    always @(posedge clk_i) begin
        if (rst_i) begin
            perf_icache_pending_reads <= '0;
            perf_dcache_pending_reads <= '0;
        end else begin
            perf_icache_pending_reads <= $signed(perf_icache_pending_reads) + `PERF_CTR_BITS'($signed(perf_icache_pending_read_cycle));
            perf_dcache_pending_reads <= $signed(perf_dcache_pending_reads) + `PERF_CTR_BITS'($signed(perf_dcache_pending_read_cycle));
        end
    end

    reg [`PERF_CTR_BITS-1:0] perf_icache_lat;
    reg [`PERF_CTR_BITS-1:0] perf_dcache_lat;

    always @(posedge clk_i) begin
        if (rst_i) begin
            perf_ifetches   <= '0;
            perf_loads      <= '0;
            perf_stores     <= '0;
            perf_icache_lat <= '0;
            perf_dcache_lat <= '0;
        end else begin
            perf_ifetches   <= perf_ifetches   + `PERF_CTR_BITS'(perf_icache_req_fire);
            perf_loads      <= perf_loads      + `PERF_CTR_BITS'(perf_dcache_rd_req_per_cycle);
            perf_stores     <= perf_stores     + `PERF_CTR_BITS'(perf_dcache_wr_req_per_cycle);
            perf_icache_lat <= perf_icache_lat + perf_icache_pending_reads;
            perf_dcache_lat <= perf_dcache_lat + perf_dcache_pending_reads;
        end
    end

    assign pipeline_perf_if.ifetches = perf_ifetches;
    assign pipeline_perf_if.loads = perf_loads;
    assign pipeline_perf_if.stores = perf_stores;
    assign pipeline_perf_if.load_latency = perf_dcache_lat;
    assign pipeline_perf_if.ifetch_latency = perf_icache_lat;
    assign pipeline_perf_if.load_latency = perf_dcache_lat;

`endif

endmodule
