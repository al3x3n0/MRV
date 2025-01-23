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


////////////////////////////////////////////////////////////////////////////////
// This is an implementation of a MSHR for pipelined multi-banked cache.
// We allocate a free slot from the MSHR before processing a core request
// and release the slot when we get a cache hit. This ensure that we do not
// enter the cache bank pipeline when the MSHR is full.
// During a memory fill response, we initiate the replay sequence
// and dequeue all pending entries for the given cache line.
//
// Pending core requests stored in the MSHR are sorted by the order of
// arrival and are dequeued in the same order.
// Each entry has a next pointer to the next entry pending for the same cache line.
//
// During the fill request, the MSHR will dequue the MSHR entry at the fill_id location
// which represents the first request in the pending list that initiated the memory fill.
//
// The dequeue response directly follows the fill request and will release
// all the subsequent entries linked to fill_id (pending the same cache line).
//
// During the allocation request, the MSHR will allocate the next free slot
// for the incoming core request. We return the allocated slot id as well as
// the slot id of the previous entry for the same cache line. This is used to
// link the new entry to the pending list.
//
// The finalize request is used to persit or release the currently allocated MSHR entry
// if we had a cache miss or a hit, respectively.
//
// Warning: This MSHR implementation is strongly coupled with the bank pipeline
// and as such changes to either module requires careful evaluation.
////////////////////////////////////////////////////////////////////////////////

module xrv_cache_mshr #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P  = 64,
    parameter MEM_ADDR_WIDTH_P = (XLEN_P == 32 ? 32 : 48),
    ////////////////////////////////////////////////////////////////////////////////
    parameter `STRING INSTANCE_ID= "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter BANK_ID_P           = 0,
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CACHE_DEFAULT_PARAMS,
    ////////////////////////////////////////////////////////////////////////////////
    // Miss Reserv Queue Knob
    ////////////////////////////////////////////////////////////////////////////////
    parameter MSHR_SIZE_P        = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Request debug identifier
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P        = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // MSHR parameters
    ////////////////////////////////////////////////////////////////////////////////
    parameter DATA_WIDTH        = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Enable cache writeback
    ////////////////////////////////////////////////////////////////////////////////
    parameter HAS_WRITEBACK_P         = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter MSHR_ADDR_WIDTH   = `XM_LOG2UP(MSHR_SIZE_P),
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CACHE_LOCALPARAMS
    ////////////////////////////////////////////////////////////////////////////////
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 clk_i,
    input logic                                 rst_i,
    ////////////////////////////////////////////////////////////////////////////////
`IGNORE_UNUSED_BEGIN
    input logic[`XM_UP(UUID_WIDTH_P)-1:0]         deq_req_uuid,
    input logic[`XM_UP(UUID_WIDTH_P)-1:0]         alc_req_uuid,
    input logic[`XM_UP(UUID_WIDTH_P)-1:0]         fin_req_uuid,
`IGNORE_UNUSED_END
    ////////////////////////////////////////////////////////////////////////////////
    // memory fill
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 fill_vld,
    input logic [MSHR_ADDR_WIDTH-1:0]           fill_id,
    output logic [CACHE_LINE_ADDR_WIDTH_LP-1:0] fill_addr,
    ////////////////////////////////////////////////////////////////////////////////
    // dequeue
    ////////////////////////////////////////////////////////////////////////////////
    output logic                                dequeue_vld,
    output logic [CACHE_LINE_ADDR_WIDTH_LP-1:0] dequeue_addr,
    output logic                                dequeue_rw,
    output logic [DATA_WIDTH-1:0]               dequeue_data,
    output logic [MSHR_ADDR_WIDTH-1:0]          dequeue_id,
    input logic                                 dequeue_rdy,
    ////////////////////////////////////////////////////////////////////////////////
    // allocate
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 allocate_vld,
    input logic [CACHE_LINE_ADDR_WIDTH_LP-1:0]  allocate_addr,
    input logic                                 allocate_rw,
    input logic [DATA_WIDTH-1:0]                allocate_data,
    output logic [MSHR_ADDR_WIDTH-1:0]          allocate_id,
    output logic                                allocate_pending,
    output logic [MSHR_ADDR_WIDTH-1:0]          allocate_previd,
    output logic                                allocate_rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    // finalize
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 finalize_vld,
    input logic                                 finalize_is_release,
    input logic                                 finalize_is_pending,
    input logic [MSHR_ADDR_WIDTH-1:0]           finalize_previd,
    input logic [MSHR_ADDR_WIDTH-1:0]           finalize_id
);
    `XM_UNUSED_PARAM (BANK_ID_P)

    logic [CACHE_LINE_ADDR_WIDTH_LP-1:0] addr_table [0:MSHR_SIZE_P-1];
    logic [MSHR_ADDR_WIDTH-1:0] next_index [0:MSHR_SIZE_P-1];

    logic [MSHR_SIZE_P-1:0] vld_table, vld_table_n;
    logic [MSHR_SIZE_P-1:0] next_table, next_table_x, next_table_n;
    logic [MSHR_SIZE_P-1:0] write_table;

    logic allocate_rdy, allocate_rdy_n;
    logic [MSHR_ADDR_WIDTH-1:0] allocate_id_r, allocate_id_n;

    logic dequeue_val, dequeue_val_n;
    logic [MSHR_ADDR_WIDTH-1:0] dequeue_id_r, dequeue_id_n;

    logic [MSHR_ADDR_WIDTH-1:0] prev_idx;

    wire allocate_fire = allocate_vld && allocate_rdy;
    wire dequeue_fire = dequeue_vld && dequeue_rdy;

    logic [MSHR_SIZE_P-1:0] addr_matches;
    for (genvar i = 0; i < MSHR_SIZE_P; ++i) begin : g_addr_matches
        assign addr_matches[i] = vld_table[i] && (addr_table[i] == allocate_addr);
    end

    xrv_lzc #(
        .N              (MSHR_SIZE_P),
        .REVERSE_P      (1)
    ) allocate_sel (
        .data_i         (~vld_table_n),
        .data_o         (allocate_id_n),
        .vld_o          (allocate_rdy_n)
    );

    // find matching tail-entry
    xrv_priority_encoder #(
        .N (MSHR_SIZE_P)
    ) prev_sel (
        .data_i             (addr_matches & ~next_table_x),
        .index_o            (prev_idx),
        `XM_UNUSED_PIN      (onehot_o),
        `XM_UNUSED_PIN      (vld_o)
    );

    always @(*) begin
        vld_table_n = vld_table;
        next_table_x  = next_table;
        dequeue_val_n = dequeue_val;
        dequeue_id_n  = dequeue_id;

        if (fill_vld) begin
            dequeue_val_n = 1;
            dequeue_id_n = fill_id;
        end

        if (dequeue_fire) begin
            vld_table_n[dequeue_id] = 0;
            if (next_table[dequeue_id]) begin
                dequeue_id_n = next_index[dequeue_id];
            end else if (finalize_vld && finalize_is_pending && (finalize_previd == dequeue_id)) begin
                dequeue_id_n = finalize_id;
            end else begin
                dequeue_val_n = 0;
            end
        end

        if (finalize_vld) begin
            if (finalize_is_release) begin
                vld_table_n[finalize_id] = 0;
            end
            // warning: This code allows 'finalize_is_pending' to be asserted regardless of hit/miss
            // to reduce the its propagation delay into the MSHR. this is safe because wrong updates
            // to 'next_table_n' will be cleared during 'allocate_fire' below.
            if (finalize_is_pending) begin
                next_table_x[finalize_previd] = 1;
            end
        end

        next_table_n = next_table_x;
        if (allocate_fire) begin
            vld_table_n[allocate_id] = 1;
            next_table_n[allocate_id] = 0;
        end
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            vld_table  <= '0;
            allocate_rdy <= 0;
            dequeue_val  <= 0;
        end else begin
            vld_table  <= vld_table_n;
            allocate_rdy <= allocate_rdy_n;
            dequeue_val  <= dequeue_val_n;
        end

        if (allocate_fire) begin
            addr_table[allocate_id] <= allocate_addr;
            write_table[allocate_id] <= allocate_rw;
        end

        if (finalize_vld && finalize_is_pending) begin
            next_index[finalize_previd] <= finalize_id;
        end

        dequeue_id_r  <= dequeue_id_n;
        allocate_id_r <= allocate_id_n;
        next_table    <= next_table_n;
    end

    `RUNTIME_ASSERT(~(allocate_fire && vld_table[allocate_id_r]), ("%t: *** %s inuse allocation: addr=0x%0h, id=%0d (#%0d)", $time, INSTANCE_ID,
        `CACHE_BANK_TO_FULL_ADDR(allocate_addr, BANK_ID_P), allocate_id_r, alc_req_uuid))

    `RUNTIME_ASSERT(~(finalize_vld && ~vld_table[finalize_id]), ("%t: *** %s invld release: addr=0x%0h, id=%0d (#%0d)", $time, INSTANCE_ID,
        `CACHE_BANK_TO_FULL_ADDR(addr_table[finalize_id], BANK_ID_P), finalize_id, fin_req_uuid))

    `RUNTIME_ASSERT(~(fill_vld && ~vld_table[fill_id]), ("%t: *** %s invld fill: addr=0x%0h, id=%0d", $time, INSTANCE_ID,
        `CACHE_BANK_TO_FULL_ADDR(addr_table[fill_id], BANK_ID_P), fill_id))

    xrv_mem_r1w1 #(
        .DATA_WIDTH_P   (DATA_WIDTH),
        .DEPTH_P        (MSHR_SIZE_P)
        // FIXME .RDW_MODE      ("R"),
        //.RADDR_REG            (1)
    ) mshr_store (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .do_wr_i        (allocate_vld),
        .wr_addr_i      (allocate_id_r),
        .wr_data_i      (allocate_data),
        .rd_addr_i      (dequeue_id_r),
        .rd_data_o      (dequeue_data)
    );

    assign fill_addr = addr_table[fill_id];

    assign allocate_rdy_o = allocate_rdy;
    assign allocate_id = allocate_id_r;
    assign allocate_previd = prev_idx;

    if (HAS_WRITEBACK_P) begin : g_pending_wb
        assign allocate_pending = |addr_matches;
    end else begin : g_pending_wt
        // exclude write requests if writethrough
        assign allocate_pending = |(addr_matches & ~write_table);
    end

    assign dequeue_vld = dequeue_val;
    assign dequeue_addr  = addr_table[dequeue_id_r];
    assign dequeue_rw    = write_table[dequeue_id_r];
    assign dequeue_id    = dequeue_id_r;

`ifdef DBG_TRACE_CACHE
    logic show_table;
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            show_table <= 0;
        end else begin
            show_table <= allocate_fire || finalize_vld || fill_vld || dequeue_fire;
        end
        if (allocate_fire) begin
            `TRACE(3, ("%t: %s allocate: addr=0x%0h, id=%0d, pending=%b, prev=%0d (#%0d)\n", $time, INSTANCE_ID,
                ``CACHE_BANK_TO_FULL_ADDR(allocate_addr, BANK_ID_P), allocate_id, allocate_pending, prev_idx, alc_req_uuid))
        end
        if (finalize_vld && finalize_is_release) begin
            `TRACE(3, ("%t: %s release: id=%0d (#%0d)\n", $time, INSTANCE_ID, finalize_id, fin_req_uuid))
        end
        if (finalize_vld && finalize_is_pending) begin
            `TRACE(3, ("%t: %s finalize: id=%0d (#%0d)\n", $time, INSTANCE_ID, finalize_id, fin_req_uuid))
        end
        if (fill_vld) begin
            `TRACE(3, ("%t: %s fill: addr=0x%0h, id=%0d\n", $time, INSTANCE_ID,
                ``CACHE_BANK_TO_FULL_ADDR(fill_addr, BANK_ID_P), fill_id))
        end
        if (dequeue_fire) begin
            `TRACE(3, ("%t: %s dequeue: addr=0x%0h, id=%0d (#%0d)\n", $time, INSTANCE_ID,
                ``CACHE_BANK_TO_FULL_ADDR(dequeue_addr, BANK_ID_P), dequeue_id_r, deq_req_uuid))
        end
        if (show_table) begin
            `TRACE(3, ("%t: %s table", $time, INSTANCE_ID))
            for (integer i = 0; i < MSHR_SIZE_P; ++i) begin
                if (vld_table[i]) begin
                    `TRACE(3, (" %0d=0x%0h", i, ``CACHE_BANK_TO_FULL_ADDR(addr_table[i], BANK_ID_P)))
                    if (write_table[i]) begin
                        `TRACE(3, ("(w)"))
                    end else begin
                        `TRACE(3, ("(r)"))
                    end
                    if (next_table[i])  begin
                        `TRACE(3, ("->%0d", next_index[i]))
                    end
                end
            end
            `TRACE(3, ("\n"))
        end
    end
`endif

endmodule
