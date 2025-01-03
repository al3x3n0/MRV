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


module xrv_elastic_buffer #(
    parameter DATA_WIDTH_P      = 1,
    parameter SIZE_P            = 1,
    parameter OUT_REG           = 0,
    parameter LUTRAM            = 0
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                        clk_i,
    input  logic                        rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                        vld_i,
    output logic                        rdy_i,
    input  logic [DATA_WIDTH_P-1:0]     data_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [DATA_WIDTH_P-1:0]     data_o,
    input  logic                        rdy_o,
    output logic                        vld_o
);
    if (SIZE_P == 0) begin : g_passthru

        `XM_UNUSED_VAR (clk_i)
        `XM_UNUSED_VAR (rst_i)

        assign vld_o = vld_i;
        assign data_o  = data_i;
        assign rdy_i  = rdy_o;

    end else if (SIZE_P == 1) begin : g_eb1

        xrv_pipe_buffer #(
            .DATA_WIDTH_P   (DATA_WIDTH_P),
            .DEPTH_P        (`XM_MAX(OUT_REG, 1))
        ) pipe_buffer (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .vld_i          (vld_i),
            .data_i         (data_i),
            .rdy_i          (rdy_i),
            .vld_o          (vld_o),
            .data_o         (data_o),
            .rdy_o          (rdy_o)
        );

    end else if (SIZE_P == 2 && LUTRAM == 0) begin : g_eb2

        logic vld_lo;
        logic [DATA_WIDTH_P-1:0] data_lo;
        logic rdy_lo;

        xrv_stream_buffer #(
            .DATA_WIDTH_P   (DATA_WIDTH_P),
            .OUT_REG        (OUT_REG == 1)
        ) stream_buffer (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .vld_i          (vld_i),
            .data_i         (data_i),
            .rdy_i          (rdy_i),
            .vld_o          (vld_lo),
            .data_o         (data_lo),
            .rdy_o          (rdy_lo)
        );

        xrv_pipe_buffer #(
            .DATA_WIDTH_P   (DATA_WIDTH_P),
            .DEPTH_P        ((OUT_REG > 1) ? (OUT_REG-1) : 0)
        ) out_buf (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .vld_i          (vld_lo),
            .data_i         (data_lo),
            .rdy_i          (rdy_lo),
            .vld_o          (vld_o),
            .data_o         (data_o),
            .rdy_o          (rdy_o)
        );

    end else begin : g_ebN

        logic empty, full;

        logic [DATA_WIDTH_P-1:0] data_lo;
        logic rdy_lo;

        logic vld_lo = ~empty;

        logic push = vld_i && rdy_i;
        logic pop = vld_lo && rdy_lo;

        xrv_fifo_queue #(
            .DATA_WIDTH_P   (DATA_WIDTH_P),
            .DEPTH_P        (SIZE_P),
            .OUT_REG        (OUT_REG == 1),
            .LUTRAM         (LUTRAM)
        ) fifo_queue (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .push           (push),
            .pop            (pop),
            .data_i         (data_i),
            .data_o         (data_lo),
            .empty          (empty),
            .full           (full),
            `XM_UNUSED_PIN     (alm_empty),
            `XM_UNUSED_PIN     (alm_full),
            `XM_UNUSED_PIN     (size)
        );

        assign rdy_i = ~full;

        xrv_pipe_buffer #(
            .DATA_WIDTH_P   (DATA_WIDTH_P),
            .DEPTH_P        ((OUT_REG > 1) ? (OUT_REG-1) : 0)
        ) out_buf (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .vld_i          (vld_lo),
            .data_i         (data_lo),
            .rdy_i          (rdy_lo),
            .vld_o          (vld_o),
            .data_o         (data_o),
            .rdy_o          (rdy_o)
        );

    end

endmodule
`TRACING_ON
