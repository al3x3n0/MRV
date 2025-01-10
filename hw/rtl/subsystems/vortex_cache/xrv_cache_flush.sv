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


module xrv_cache_flush #(
    ////////////////////////////////////////////////////////////////////////////////
    // Number of Word requests per cycle
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_REQS_P  = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Number of banks
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_BANKS_P = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Request debug identifier
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // core request tag size
    ////////////////////////////////////////////////////////////////////////////////
    parameter TAG_WIDTH_P = UUID_WIDTH_P + 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Bank select latency
    ////////////////////////////////////////////////////////////////////////////////
    parameter BANK_SEL_LATENCY_P = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter HAS_WRITEBACK_P = 0
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 clk_i,
    input logic                                 rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    xrv_cache_if.slave                          core_bus_in_if  [NUM_REQS_P],
    xrv_cache_if.master                         core_bus_out_if [NUM_REQS_P],
    ////////////////////////////////////////////////////////////////////////////////
    // Core -> Flush
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [NUM_BANKS_P-1:0]            bank_req_fire_i,
    output logic [NUM_BANKS_P-1:0]            flush_begin_o,
    output logic [`XM_UP(UUID_WIDTH_P)-1:0]   flush_uuid_o,
    input  logic [NUM_BANKS_P-1:0]            flush_end_i
);

   `XM_UNUSED_PARAM (TAG_WIDTH_P)

    localparam STATE_IDLE  = 0;
    localparam STATE_WAIT1 = 1;
    localparam STATE_FLUSH = 2;
    localparam STATE_WAIT2 = 3;
    localparam STATE_DONE  = 4;

    logic [2:0] state, state_n;

    // track in-flight core requests

    logic no_inflight_reqs;

    if (BANK_SEL_LATENCY_P != 0) begin : g_bank_sel_latency

        localparam NUM_REQS_WIDTH_LP  = `XM_CLOG2(NUM_REQS_P+1);
        localparam NUM_BANKS_WIDTH_LP = `XM_CLOG2(NUM_BANKS_P+1);

        logic [NUM_REQS_P-1:0] core_bus_out_fire;
        for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_bus_out_fire
            assign core_bus_out_fire[i] = core_bus_out_if[i].req_vld && core_bus_out_if[i].req_rdy;
        end

        logic [NUM_REQS_WIDTH_LP-1:0] core_bus_out_cnt;
        logic [NUM_BANKS_WIDTH_LP-1:0] bank_req_cnt;

        `POP_COUNT(core_bus_out_cnt, core_bus_out_fire);
        `POP_COUNT(bank_req_cnt, bank_req_fire_i);
        `XM_UNUSED_VAR (core_bus_out_cnt)

        xrv_pending_size #(
            .SIZE_P             (BANK_SEL_LATENCY_P * NUM_BANKS_P),
            .INCR_WIDTH_P       (NUM_BANKS_WIDTH_LP),
            .DECR_WIDTH_P       (NUM_BANKS_WIDTH_LP)
        ) pending_size (
            .clk_i                  (clk_i),
            .rst_i                  (rst_i),
            .incr                   (NUM_BANKS_WIDTH_LP'(core_bus_out_cnt)),
            .decr                   (bank_req_cnt),
            .empty                  (no_inflight_reqs),
            `XM_UNUSED_PIN          (alm_empty),
            `XM_UNUSED_PIN          (full),
            `XM_UNUSED_PIN          (alm_full),
            `XM_UNUSED_PIN          (size)
        );

    end else begin : g_no_bank_sel_latency
        assign no_inflight_reqs = 0;
        `XM_UNUSED_VAR (bank_req_fire_i)
    end

    logic [NUM_BANKS_P-1:0] flush_done, flush_done_n;

    logic [NUM_REQS_P-1:0] flush_req_mask;
    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_flush_req_mask
        assign flush_req_mask[i] = core_bus_in_if[i].req_vld && core_bus_in_if[i].req_data.flags[`MEM_REQ_FLAG_FLUSH];
    end
    wire flush_req_enable = (| flush_req_mask);

    logic [NUM_REQS_P-1:0] lock_released, lock_released_n;
    logic [`XM_UP(UUID_WIDTH_P)-1:0] flush_uuid_r, flush_uuid_n;

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_bus_out_req
        wire input_enable = ~flush_req_enable || lock_released[i];
        assign core_bus_out_if[i].req_vld = core_bus_in_if[i].req_vld && input_enable;
        assign core_bus_out_if[i].req_data  = core_bus_in_if[i].req_data;
        assign core_bus_in_if[i].req_rdy  = core_bus_out_if[i].req_rdy && input_enable;
    end

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_bus_in_resp
        assign core_bus_in_if[i].resp_vld  = core_bus_out_if[i].resp_vld;
        assign core_bus_in_if[i].resp_data   = core_bus_out_if[i].resp_data;
        assign core_bus_out_if[i].resp_rdy = core_bus_in_if[i].resp_rdy;
    end

    logic [NUM_REQS_P-1:0][`XM_UP(UUID_WIDTH_P)-1:0] core_bus_out_uuid;
    logic [NUM_REQS_P-1:0] core_bus_out_rdy;
    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_bus_out_uuid
        if (UUID_WIDTH_P != 0) begin : g_uuid
            assign core_bus_out_uuid[i] = core_bus_in_if[i].req_data.tag.uuid;
        end else begin : g_no_uuid
            assign core_bus_out_uuid[i] = 0;
        end
    end

    for (genvar i = 0; i < NUM_REQS_P; ++i) begin : g_core_bus_out_rdy
        assign core_bus_out_rdy[i] = core_bus_out_if[i].req_rdy;
    end

    always_comb begin
        state_n = state;
        flush_done_n = flush_done;
        lock_released_n = lock_released;
        flush_uuid_n = flush_uuid_r;
        case (state)
            //STATE_IDLE:
            default: begin
                if (flush_req_enable) begin
                    state_n = (BANK_SEL_LATENCY_P != 0) ? STATE_WAIT1 : STATE_FLUSH;
                    for (integer i = NUM_REQS_P-1; i >= 0; --i) begin
                        if (flush_req_mask[i]) begin
                            flush_uuid_n = core_bus_out_uuid[i];
                        end
                    end
                end
            end
            STATE_WAIT1: begin
                if (no_inflight_reqs) begin
                    state_n = STATE_FLUSH;
                end
            end
            STATE_FLUSH: begin
                // generate a flush request pulse
                state_n = STATE_WAIT2;
            end
            STATE_WAIT2: begin
                // wait for all banks to finish flushing
                flush_done_n = flush_done | flush_end_i;
                if (flush_done_n == {NUM_BANKS_P{1'b1}}) begin
                    state_n = STATE_DONE;
                    flush_done_n = '0;
                    // only release current flush requests
                    // and keep normal requests locked
                    lock_released_n = flush_req_mask;
                end
            end
            STATE_DONE: begin
                // wait until released flush requests are issued
                // when returning to IDLE state other requests will unlock
                lock_released_n = lock_released & ~core_bus_out_rdy;
                if (lock_released_n == 0) begin
                    state_n = STATE_IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state <= STATE_IDLE;
            flush_done <= '0;
            lock_released <= '0;
        end else begin
            state <= state_n;
            flush_done <= flush_done_n;
            lock_released <= lock_released_n;
        end
        flush_uuid_r <= flush_uuid_n;
    end

    assign flush_begin_o = {NUM_BANKS_P{state == STATE_FLUSH}};
    assign flush_uuid_o = flush_uuid_r;

endmodule
