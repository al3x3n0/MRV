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


module xrv_bank_flush #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                    = 64,
    parameter MEM_ADDR_WIDTH_P          = XLEN_P,
    ////////////////////////////////////////////////////////////////////////////////
    parameter BANK_ID_P                 = 0,
    parameter HAS_WRITEBACK_P           = 0,
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CACHE_DEFAULT_PARAMS,
    `XRV_CACHE_LOCALPARAMS
) (
    input  logic clk_i,
    input  logic rst_i,
    input  logic flush_begin,
    output logic flush_end,
    output logic flush_init,
    output logic flush_vld,
    output logic [CACHE_LINE_SEL_BITS_LP-1:0] flush_line,
    output logic [CACHE_WAY_SEL_WIDTH_LP-1:0] flush_way,
    input  logic flush_rdy,
    input  logic mshr_empty,
    input  logic bank_empty
);
    // ways interation is only needed when eviction is enabled
    localparam CTR_WIDTH = CACHE_LINE_SEL_BITS_LP + (HAS_WRITEBACK_P ? CACHE_WAY_SEL_BITS_LP : 0);

    localparam STATE_IDLE  = 0;
    localparam STATE_INIT  = 1;
    localparam STATE_WAIT1 = 2;
    localparam STATE_FLUSH = 3;
    localparam STATE_WAIT2 = 4;
    localparam STATE_DONE  = 5;

    reg [2:0] state, state_n;

    reg [CTR_WIDTH-1:0] counter;

    always @(*) begin
        state_n = state;
        case (state)
            //STATE_IDLE:
            default : begin
                if (flush_begin) begin
                    state_n = STATE_WAIT1;
                end
            end
            STATE_INIT: begin
                if (counter == ((2 ** CACHE_LINE_SEL_BITS_LP)-1)) begin
                    state_n = STATE_IDLE;
                end
            end
            STATE_WAIT1: begin
                // wait for pending requests to complete
                if (mshr_empty) begin
                    state_n = STATE_FLUSH;
                end
            end
            STATE_FLUSH: begin
                if (counter == ((2 ** CTR_WIDTH)-1) && flush_rdy) begin
                    state_n = (BANK_ID_P == 0) ? STATE_DONE : STATE_WAIT2;
                end
            end
            STATE_WAIT2: begin
                // ensure the bank is empty before notifying the cache flush unit,
                // because the flush request to lower caches only goes through bank0
                // and it is important that request gets send out last.
                if (bank_empty) begin
                    state_n = STATE_DONE;
                end
            end
            STATE_DONE: begin
                // generate a completion pulse
                state_n = STATE_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state   <= STATE_INIT;
            counter <= '0;
        end else begin
            state <= state_n;
            if (state != STATE_IDLE) begin
                if ((state == STATE_INIT)
                || ((state == STATE_FLUSH) && flush_rdy)) begin
                    counter <= counter + CTR_WIDTH'(1);
                end
            end else begin
                counter <= '0;
            end
        end
    end

    assign flush_end   = (state == STATE_DONE);
    assign flush_init  = (state == STATE_INIT);
    assign flush_vld = (state == STATE_FLUSH);
    assign flush_line  = counter[CACHE_LINE_SEL_BITS_LP-1:0];

    if (HAS_WRITEBACK_P && (NUM_WAYS_P > 1)) begin : g_flush_way
        assign flush_way = counter[CACHE_LINE_SEL_BITS_LP +: CACHE_WAY_SEL_BITS_LP];
    end else begin : g_flush_way_all
        assign flush_way = '0;
    end

endmodule
