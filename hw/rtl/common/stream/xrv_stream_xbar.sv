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


module xrv_stream_xbar #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_INPUTS_P              = 4,
    parameter NUM_OUTPUTS_P             = 4,
    parameter DATA_WIDTH_P              = 4,
    parameter ARBITER_TYPE_P            = "R",
    parameter OUT_BUF                   = 0,
    parameter MAX_FANOUT                = 8,
    ////////////////////////////////////////////////////////////////////////////////
    parameter PERF_CTR_BITS             = `XM_CLOG2(NUM_INPUTS_P+1),
    parameter IN_WIDTH_LP               = `XM_LOG2UP(NUM_INPUTS_P),
    parameter OUT_WIDTH_LP              = `XM_LOG2UP(NUM_OUTPUTS_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                          clk_i,
    input logic                                          rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [NUM_INPUTS_P-1:0]                       vld_i,
    input logic [NUM_INPUTS_P-1:0][DATA_WIDTH_P-1:0]     data_i,
    input logic [NUM_INPUTS_P-1:0][OUT_WIDTH_LP-1:0]     sel_i,
    output logic [NUM_INPUTS_P-1:0]                      rdy_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_OUTPUTS_P-1:0]                     vld_o,
    output logic [NUM_OUTPUTS_P-1:0][DATA_WIDTH_P-1:0]   data_o,
    output logic [NUM_OUTPUTS_P-1:0][IN_WIDTH_LP-1:0]    sel_o,
    input  logic [NUM_OUTPUTS_P-1:0]                     rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [PERF_CTR_BITS-1:0]                     collisions_o
);
    if (NUM_INPUTS_P != 1) begin : g_multi_inputs

        if (NUM_OUTPUTS_P != 1) begin : g_multiple_outputs

            // (#inputs > 1) and (#outputs > 1)

            logic [NUM_INPUTS_P-1:0][NUM_OUTPUTS_P-1:0] per_output_vld_i;
            logic [NUM_OUTPUTS_P-1:0][NUM_INPUTS_P-1:0] per_output_vld_i_w;

            logic [NUM_OUTPUTS_P-1:0][NUM_INPUTS_P-1:0] per_output_rdy_i;
            logic [NUM_INPUTS_P-1:0][NUM_OUTPUTS_P-1:0] per_output_rdy_i_w;

            xrv_transpose #(
                .N_P    (NUM_OUTPUTS_P),
                .M_P    (NUM_INPUTS_P)
            ) rdy_in_transpose (
                .data_i (per_output_rdy_i),
                .data_o (per_output_rdy_i_w)
            );

            for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_rdy_i
                assign rdy_i[i] = | per_output_rdy_i_w[i];
            end

            for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_sel_i_demux
                xrv_demux #(
                    .DATA_WIDTH_P (1),
                    .N (NUM_OUTPUTS_P)
                ) sel_i_demux (
                    .sel_i   (sel_i[i]),
                    .data_i  (vld_i[i]),
                    .data_o (per_output_vld_i[i])
                );
            end

            xrv_transpose #(
                .N_P    (NUM_INPUTS_P),
                .M_P    (NUM_OUTPUTS_P)
            ) val_in_transpose (
                .data_i (per_output_vld_i),
                .data_o (per_output_vld_i_w)
            );

            for (genvar i = 0; i < NUM_OUTPUTS_P; ++i) begin : g_xbar_arbs
                xrv_stream_arb #(
                    .NUM_INPUTS_P       (NUM_INPUTS_P),
                    .NUM_OUTPUTS_P      (1),
                    .DATA_WIDTH_P       (DATA_WIDTH_P),
                    .ARBITER_TYPE_P     (ARBITER_TYPE_P),
                    .MAX_FANOUT         (MAX_FANOUT),
                    .OUT_BUF            (OUT_BUF)
                ) xbar_arb (
                    .clk_i              (clk_i),
                    .rst_i              (rst_i),
                    .vld_i              (per_output_vld_i_w[i]),
                    .data_i             (data_i),
                    .rdy_i              (per_output_rdy_i[i]),
                    .vld_o              (vld_o[i]),
                    .data_o             (data_o[i]),
                    .sel_o              (sel_o[i]),
                    .rdy_o              (rdy_o[i])
                );
            end

        end else begin : g_one_output

            // (#inputs >= 1) and (#outputs == 1)

            xrv_stream_arb #(
                .NUM_INPUTS_P       (NUM_INPUTS_P),
                .NUM_OUTPUTS_P      (1),
                .DATA_WIDTH_P       (DATA_WIDTH_P),
                .ARBITER_TYPE_P     (ARBITER_TYPE_P),
                .MAX_FANOUT         (MAX_FANOUT),
                .OUT_BUF            (OUT_BUF)
            ) xbar_arb (
                .clk_i              (clk_i),
                .rst_i              (rst_i),
                .vld_i              (vld_i),
                .data_i             (data_i),
                .rdy_i              (rdy_i),
                .vld_o              (vld_o),
                .data_o             (data_o),
                .sel_o              (sel_o),
                .rdy_o              (rdy_o)
            );

            `XM_UNUSED_VAR (sel_i)
        end

    end else if (NUM_OUTPUTS_P != 1) begin : g_single_input

        // (#inputs == 1) and (#outputs > 1)

        logic [NUM_OUTPUTS_P-1:0] vld_o_w, rdy_o_w;
        logic [NUM_OUTPUTS_P-1:0][DATA_WIDTH_P-1:0] data_o_w;

        xrv_demux #(
            .DATA_WIDTH_P (1),
            .N (NUM_OUTPUTS_P)
        ) sel_i_demux (
            .sel_i   (sel_i[0]),
            .data_i  (vld_i[0]),
            .data_o (vld_o_w)
        );

        assign rdy_i[0] = rdy_o_w[sel_i[0]];
        assign data_o_w = {NUM_OUTPUTS_P{data_i[0]}};

        for (genvar i = 0; i < NUM_OUTPUTS_P; ++i) begin : g_out_buf
            xrv_elastic_buffer #(
                .DATA_WIDTH_P   (DATA_WIDTH_P),
                .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
                .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF)),
                .LUTRAM         (`XM_TO_OUT_BUF_LUTRAM(OUT_BUF))
            ) out_buf (
                .clk_i          (clk_i),
                .rst_i          (rst_i),
                .vld_i          (vld_o_w[i]),
                .rdy_i          (rdy_o_w[i]),
                .data_i         (data_o_w[i]),
                .data_o         (data_o[i]),
                .vld_o          (vld_o[i]),
                .rdy_o          (rdy_o[i])
            );
        end

        assign sel_o = 0;

    end else begin : g_passthru

        // (#inputs == 1) and (#outputs == 1)

        xrv_elastic_buffer #(
            .DATA_WIDTH_P   (DATA_WIDTH_P),
            .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
            .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF)),
            .LUTRAM         (`XM_TO_OUT_BUF_LUTRAM(OUT_BUF))
        ) out_buf (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            .vld_i          (vld_i),
            .rdy_i          (rdy_i),
            .data_i         (data_i),
            .data_o         (data_o),
            .vld_o          (vld_o),
            .rdy_o          (rdy_o)
        );

        `XM_UNUSED_VAR (sel_i)
        assign sel_o = 0;

    end

    // compute inputs collision
    // we have a collision when there exists a vld transfer with multiple input candicates
    // we count the unique duplicates each cycle.

    reg [NUM_INPUTS_P-1:0] per_cycle_collision, per_cycle_collision_r;
    logic [`XM_CLOG2(NUM_INPUTS_P+1)-1:0] collision_count;
    reg [PERF_CTR_BITS-1:0] collisions_r;

    always_comb begin
        per_cycle_collision = 0;
        for (integer i = 0; i < NUM_INPUTS_P; ++i) begin
            for (integer j = 1; j < (NUM_INPUTS_P-i); ++j) begin
                per_cycle_collision[i] |= vld_i[i]
                                       && vld_i[j+i]
                                       && (sel_i[i] == sel_i[j+i])
                                       && (rdy_i[i] | rdy_i[j+i]);
            end
        end
    end

    `XM_BUFFER(per_cycle_collision_r, per_cycle_collision);
    `POP_COUNT(collision_count, per_cycle_collision_r);

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            collisions_r <= '0;
        end else begin
            collisions_r <= collisions_r + PERF_CTR_BITS'(collision_count);
        end
    end

    assign collisions_o = collisions_r;

endmodule
