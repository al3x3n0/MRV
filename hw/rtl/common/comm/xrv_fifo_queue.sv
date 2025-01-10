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


`TRACING_OFF
module xrv_fifo_queue #(
    parameter DATA_WIDTH_P  = 32,
    parameter DEPTH_P       = 32,
    parameter ALM_FULL_P    = (DEPTH_P - 1),
    parameter ALM_EMPTY_P   = 1,
    parameter OUT_REG       = 0,
    parameter LUTRAM        = 0,
    parameter SIZEW         = `XM_CLOG2(DEPTH_P+1)
) (
    input  logic             clk_i,
    input  logic             rst_i,
    input  logic             push,
    input  logic             pop,
    input  logic [DATA_WIDTH_P-1:0] data_i,
    output logic [DATA_WIDTH_P-1:0] data_o,
    output logic             empty,
    output logic             alm_empty,
    output logic             full,
    output logic             alm_full,
    output logic [SIZEW-1:0] size
);

    `STATIC_ASSERT(ALM_FULL_P > 0, ("alm_full must be greater than 0!"))
    `STATIC_ASSERT(ALM_FULL_P < DEPTH_P, ("alm_full must be smaller than size!"))
    `STATIC_ASSERT(ALM_EMPTY_P > 0, ("alm_empty must be greater than 0!"))
    `STATIC_ASSERT(ALM_EMPTY_P < DEPTH_P, ("alm_empty must be smaller than size!"))
    `STATIC_ASSERT(`XM_IS_POW2(DEPTH_P), ("depth must be a power of 2!"))

    xrv_pending_size #(
        .SIZE_P         (DEPTH_P),
        .ALM_EMPTY_P    (ALM_EMPTY_P),
        .ALM_FULL_P     (ALM_FULL_P)
    ) pending_size (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .incr           (push),
        .decr           (pop),
        .empty          (empty),
        .full           (full),
        .alm_empty      (alm_empty),
        .alm_full       (alm_full),
        .size           (size)
    );

    if (DEPTH_P == 1) begin : g_depth_1
        `XM_UNUSED_PARAM (OUT_REG)
        `XM_UNUSED_PARAM (LUTRAM)

        reg [DATA_WIDTH_P-1:0] head_r;

        always @(posedge clk_i) begin
            if (push) begin
                head_r <= data_i;
            end
        end

        assign data_o = head_r;

    end else begin : g_depth_n

        localparam ADDRW = `XM_CLOG2(DEPTH_P);

        logic [DATA_WIDTH_P-1:0] data_o_w;
        reg [ADDRW-1:0] rd_ptr_r;
        reg [ADDRW-1:0] wr_ptr_r;

        always @(posedge clk_i) begin
            if (rst_i) begin
                wr_ptr_r <= '0;
                rd_ptr_r <= (OUT_REG != 0) ? 1 : 0;
            end else begin
                wr_ptr_r <= wr_ptr_r + ADDRW'(push);
                rd_ptr_r <= rd_ptr_r + ADDRW'(pop);
            end
        end

        xrv_mem_r1w1 #(
            .DATA_WIDTH_P   (DATA_WIDTH_P),
            .DEPTH_P        (DEPTH_P)
            // FIXME .LUTRAM (LUTRAM),
            //.RDW_MODE ("W"),
            //.RADDR_REG (1)
        ) dp_ram (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .do_wr_i        (push),
            .rd_addr_i      (rd_ptr_r),
            .wr_addr_i      (wr_ptr_r),
            .wr_data_i      (data_i),
            .rd_data_o      (data_o_w)
        );

        if (OUT_REG != 0) begin : g_out_reg
            reg [DATA_WIDTH_P-1:0] data_o_r;
            wire going_empty = (ALM_EMPTY_P == 1) ? alm_empty : (size[ADDRW-1:0] == ADDRW'(1));
            wire bypass = push && (empty || (going_empty && pop));
            always @(posedge clk_i) begin
                if (bypass) begin
                    data_o_r <= data_i;
                end else if (pop) begin
                    data_o_r <= data_o_w;
                end
            end
            assign data_o = data_o_r;
        end else begin : g_no_out_reg
            assign data_o = data_o_w;
        end
    end

    `RUNTIME_ASSERT(~(push && ~pop) || ~full, ("%t: runtime error: incrementing full queue", $time))
    `RUNTIME_ASSERT(~(pop && ~push) || ~empty, ("%t: runtime error: decrementing empty queue", $time))

endmodule
`TRACING_ON
