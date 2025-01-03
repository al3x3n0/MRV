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


module xrv_stream_arb #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_INPUTS_P              = 1,
    parameter NUM_OUTPUTS_P             = 1,
    parameter DATA_WIDTH_P              = 1,
    parameter `STRING ARBITER_TYPE_P    = "R",
    parameter MAX_FANOUT                = `MAX_FANOUT,
    parameter OUT_BUF                   = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_REQS              = (NUM_INPUTS_P > NUM_OUTPUTS_P) ? `XM_CDIV(NUM_INPUTS_P, NUM_OUTPUTS_P) : `XM_CDIV(NUM_OUTPUTS_P, NUM_INPUTS_P),
    parameter SEL_COUNT             = `XM_MIN(NUM_INPUTS_P, NUM_OUTPUTS_P),
    parameter LOG_NUM_REQS          = $clog2(NUM_REQS),
    parameter NUM_REQS_W            = `XM_UP(LOG_NUM_REQS)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        clk_i,
    input  logic                                        rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [NUM_INPUTS_P-1:0]                     vld_i,
    input  logic [NUM_INPUTS_P-1:0][DATA_WIDTH_P-1:0]   data_i,
    output logic [NUM_INPUTS_P-1:0]                     rdy_i,
    output logic [NUM_OUTPUTS_P-1:0]                    vld_o,
    output logic [NUM_OUTPUTS_P-1:0][DATA_WIDTH_P-1:0]  data_o,
    input  logic [NUM_OUTPUTS_P-1:0]                    rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [SEL_COUNT-1:0][NUM_REQS_W-1:0]        sel_o
);
    if (NUM_INPUTS_P > NUM_OUTPUTS_P) begin : g_input_select

        // #Inputs > #Outputs

        if (MAX_FANOUT != 0 && (NUM_REQS > (MAX_FANOUT + MAX_FANOUT /2))) begin : g_fanout

            localparam NUM_SLICES    = `XM_CDIV(NUM_REQS, MAX_FANOUT);
            localparam LOG_NUM_REQS2 = $clog2(MAX_FANOUT);
            localparam LOG_NUM_REQS3 = $clog2(NUM_SLICES);
            localparam DATA_WIDTH_P2 = DATA_WIDTH_P + LOG_NUM_REQS2;

            logic [NUM_SLICES-1:0][NUM_OUTPUTS_P-1:0] vld_tmp;
            logic [NUM_SLICES-1:0][NUM_OUTPUTS_P-1:0][DATA_WIDTH_P2-1:0] data_tmp;
            logic [NUM_SLICES-1:0][NUM_OUTPUTS_P-1:0] rdy_tmp;

            for (genvar s = 0; s < NUM_SLICES; ++s) begin : g_slice_arbs

                localparam SLICE_STRIDE= MAX_FANOUT * NUM_OUTPUTS_P;
                localparam SLICE_BEGIN = s * SLICE_STRIDE;
                localparam SLICE_END   = `XM_MIN(SLICE_BEGIN + SLICE_STRIDE, NUM_INPUTS_P);
                localparam SLICE_SIZE  = SLICE_END - SLICE_BEGIN;

                logic [NUM_OUTPUTS_P-1:0][DATA_WIDTH_P-1:0] data_tmp_u;
                logic [NUM_OUTPUTS_P-1:0][LOG_NUM_REQS2-1:0] sel_tmp_u;

                xrv_stream_arb #(
                    .NUM_INPUTS_P       (SLICE_SIZE),
                    .NUM_OUTPUTS_P      (NUM_OUTPUTS_P),
                    .DATA_WIDTH_P       (DATA_WIDTH_P),
                    .ARBITER_TYPE_P     (ARBITER_TYPE_P),
                    .MAX_FANOUT         (MAX_FANOUT),
                    .OUT_BUF            (3)
                ) fanout_slice_arb (
                    .clk_i              (clk_i),
                    .rst_i              (rst_i),
                    .vld_i              (vld_i[SLICE_END-1: SLICE_BEGIN]),
                    .data_i             (data_i[SLICE_END-1: SLICE_BEGIN]),
                    .rdy_i              (rdy_i[SLICE_END-1: SLICE_BEGIN]),
                    .vld_o              (vld_tmp[s]),
                    .data_o             (data_tmp_u),
                    .rdy_o              (rdy_tmp[s]),
                    .sel_o              (sel_tmp_u)
                );

                for (genvar o = 0; o < NUM_OUTPUTS_P; ++o) begin : g_data_tmp
                    assign data_tmp[s][o] = {data_tmp_u[o], sel_tmp_u[o]};
                end
            end

            logic [NUM_OUTPUTS_P-1:0][DATA_WIDTH_P2-1:0] data_out_u;
            logic [NUM_OUTPUTS_P-1:0][LOG_NUM_REQS3-1:0] sel_out_u;

            xrv_stream_arb #(
                .NUM_INPUTS_P       (NUM_SLICES * NUM_OUTPUTS_P),
                .NUM_OUTPUTS_P      (NUM_OUTPUTS_P),
                .DATA_WIDTH_P       (DATA_WIDTH_P2),
                .ARBITER_TYPE_P     (ARBITER_TYPE_P),
                .MAX_FANOUT         (MAX_FANOUT),
                .OUT_BUF            (OUT_BUF)
            ) fanout_join_arb (
                .clk_i          (clk_i),
                .rst_i          (rst_i),
                .vld_i          (vld_tmp),
                .rdy_i          (rdy_tmp),
                .data_i         (data_tmp),
                .data_o         (data_out_u),
                .sel_o          (sel_out_u),
                .vld_o          (vld_o),
                .rdy_o          (rdy_o)
            );

            for (genvar o = 0; o < NUM_OUTPUTS_P; ++o) begin : g_data_out
                assign sel_o[o]  = {sel_out_u[o], data_out_u[o][LOG_NUM_REQS2-1:0]};
                assign data_o[o] = data_out_u[o][DATA_WIDTH_P2-1:LOG_NUM_REQS2];
            end

        end else begin : g_arbiter

            logic [NUM_REQS-1:0]     arb_requests;
            logic                    arb_vld;
            logic [NUM_REQS_W-1:0]   arb_index;
            logic [NUM_REQS-1:0]     arb_onehot;
            logic                    arb_rdy;

            for (genvar r = 0; r < NUM_REQS; ++r) begin : g_requests
                logic [NUM_OUTPUTS_P-1:0] requests;
                for (genvar o = 0; o < NUM_OUTPUTS_P; ++o) begin : g_o
                    localparam i = r * NUM_OUTPUTS_P + o;
                    assign requests[o] = vld_i[i];
                end
                assign arb_requests[r] = (| requests);
            end

            xrv_generic_arbiter #(
                .NUM_REQS_P     (NUM_REQS),
                .TYPE           (ARBITER_TYPE_P)
            ) arbiter (
                .clk_i          (clk_i),
                .rst_i          (rst_i),
                .requests       (arb_requests),
                .grant_vld    (arb_vld),
                .grant_index    (arb_index),
                .grant_onehot   (arb_onehot),
                .grant_rdy    (arb_rdy)
            );

            logic [NUM_OUTPUTS_P-1:0] vld_out_w;
            logic [NUM_OUTPUTS_P-1:0][DATA_WIDTH_P-1:0] data_out_w;
            logic [NUM_OUTPUTS_P-1:0] rdy_out_w;

            for (genvar o = 0; o < NUM_OUTPUTS_P; ++o) begin : g_data_out_w
                logic [NUM_REQS-1:0] vld_in_w;
                logic [NUM_REQS-1:0][DATA_WIDTH_P-1:0] data_in_w;
                for (genvar r = 0; r < NUM_REQS; ++r) begin : g_r
                    localparam i = r * NUM_OUTPUTS_P + o;
                    if (r < NUM_INPUTS_P) begin : g_vld
                        assign vld_in_w[r] = vld_i[i];
                        assign data_in_w[r]  = data_i[i];
                    end else begin : g_padding
                        assign vld_in_w[r] = 0;
                        assign data_in_w[r]  = '0;
                    end
                end
                assign vld_out_w[o] = (NUM_OUTPUTS_P == 1) ? arb_vld : (| (vld_in_w & arb_onehot));
                assign data_out_w[o]  = data_in_w[arb_index];
            end

            for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_rdy_in
                localparam o = i % NUM_OUTPUTS_P;
                localparam r = i / NUM_OUTPUTS_P;
                assign rdy_i[i] = rdy_out_w[o] && arb_onehot[r];
            end

            assign arb_rdy = (| rdy_out_w);

            for (genvar o = 0; o < NUM_OUTPUTS_P; ++o) begin : g_out_buf
                xrv_elastic_buffer #(
                    .DATA_WIDTH_P   (LOG_NUM_REQS + DATA_WIDTH_P),
                    .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
                    .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF)),
                    .LUTRAM         (`XM_TO_OUT_BUF_LUTRAM(OUT_BUF))
                ) out_buf (
                    .clk_i      (clk_i),
                    .rst_i      (rst_i),
                    .vld_i      (vld_out_w[o]),
                    .rdy_i      (rdy_out_w[o]),
                    .data_i     ({arb_index, data_out_w[o]}),
                    .data_o     ({sel_o[o], data_o[o]}),
                    .vld_o      (vld_o[o]),
                    .rdy_o      (rdy_o[o])
                );
            end
        end

    end else if (NUM_INPUTS_P < NUM_OUTPUTS_P) begin : g_output_select

        // #Inputs < #Outputs

        if (MAX_FANOUT != 0 && (NUM_REQS > (MAX_FANOUT + MAX_FANOUT /2))) begin : g_fanout

            localparam NUM_SLICES    = `XM_CDIV(NUM_REQS, MAX_FANOUT);
            localparam LOG_NUM_REQS2 = $clog2(MAX_FANOUT);
            localparam LOG_NUM_REQS3 = $clog2(NUM_SLICES);

            logic [NUM_SLICES-1:0][NUM_INPUTS_P-1:0] vld_tmp;
            logic [NUM_SLICES-1:0][NUM_INPUTS_P-1:0][DATA_WIDTH_P-1:0] data_tmp;
            logic [NUM_SLICES-1:0][NUM_INPUTS_P-1:0] rdy_tmp;
            logic [NUM_INPUTS_P-1:0][LOG_NUM_REQS3-1:0] sel_tmp;

            xrv_stream_arb #(
                .NUM_INPUTS_P       (NUM_INPUTS_P),
                .NUM_OUTPUTS_P      (NUM_SLICES * NUM_INPUTS_P),
                .DATA_WIDTH_P       (DATA_WIDTH_P),
                .ARBITER_TYPE_P            (ARBITER_TYPE_P),
                .MAX_FANOUT         (MAX_FANOUT),
                .OUT_BUF            (3)
            ) fanout_fork_arb (
                .clk_i              (clk_i),
                .rst_i              (rst_i),
                .vld_i              (vld_i),
                .rdy_i              (rdy_i),
                .data_i             (data_i),
                .data_o             (data_tmp),
                .vld_o              (vld_tmp),
                .rdy_o              (rdy_tmp),
                .sel_o              (sel_tmp)
            );

            logic [NUM_SLICES-1:0][NUM_INPUTS_P-1:0][LOG_NUM_REQS2-1:0] sel_out_w;

            for (genvar s = 0; s < NUM_SLICES; ++s) begin : g_slice_arbs

                localparam SLICE_STRIDE= MAX_FANOUT * NUM_INPUTS_P;
                localparam SLICE_BEGIN = s * SLICE_STRIDE;
                localparam SLICE_END   = `XM_MIN(SLICE_BEGIN + SLICE_STRIDE, NUM_OUTPUTS_P);
                localparam SLICE_SIZE  = SLICE_END - SLICE_BEGIN;

                logic [NUM_INPUTS_P-1:0][LOG_NUM_REQS2-1:0] sel_out_u;

                xrv_stream_arb #(
                    .NUM_INPUTS_P       (NUM_INPUTS_P),
                    .NUM_OUTPUTS_P      (SLICE_SIZE),
                    .DATA_WIDTH_P       (DATA_WIDTH_P),
                    .ARBITER_TYPE_P            (ARBITER_TYPE_P),
                    .MAX_FANOUT         (MAX_FANOUT),
                    .OUT_BUF            (OUT_BUF)
                ) fanout_slice_arb (
                    .clk_i              (clk_i),
                    .rst_i              (rst_i),
                    .vld_i              (vld_tmp[s]),
                    .rdy_i              (rdy_tmp[s]),
                    .data_i             (data_tmp[s]),
                    .data_o             (data_o[SLICE_END-1: SLICE_BEGIN]),
                    .vld_o              (vld_o[SLICE_END-1: SLICE_BEGIN]),
                    .rdy_o              (rdy_o[SLICE_END-1: SLICE_BEGIN]),
                    .sel_o              (sel_out_w[s])
                );
            end

            for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_sel_out
                assign sel_o[i] = {sel_tmp[i], sel_out_w[sel_tmp[i]][i]};
            end

        end else begin : g_arbiter

            logic [NUM_REQS-1:0]     arb_requests;
            logic                    arb_vld;
            logic [NUM_REQS_W-1:0]   arb_index;
            logic [NUM_REQS-1:0]     arb_onehot;
            logic                    arb_rdy;

            for (genvar r = 0; r < NUM_REQS; ++r) begin : g_requests
                logic [NUM_INPUTS_P-1:0] requests;
                for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_i
                    localparam o = r * NUM_INPUTS_P + i;
                    assign requests[i] = rdy_o[o];
                end
                assign arb_requests[r] = (| requests);
            end

            xrv_generic_arbiter #(
                .NUM_REQS_P     (NUM_REQS),
                .TYPE           (ARBITER_TYPE_P)
            ) arbiter (
                .clk_i          (clk_i),
                .rst_i          (rst_i),
                .requests       (arb_requests),
                .grant_vld      (arb_vld),
                .grant_index    (arb_index),
                .grant_onehot   (arb_onehot),
                .grant_rdy      (arb_rdy)
            );

            logic [NUM_OUTPUTS_P-1:0] vld_out_w;
            logic [NUM_OUTPUTS_P-1:0][DATA_WIDTH_P-1:0] data_out_w;
            logic [NUM_OUTPUTS_P-1:0] rdy_out_w;

            for (genvar o = 0; o < NUM_OUTPUTS_P; ++o) begin : g_data_out_w
                localparam i = o % NUM_INPUTS_P;
                localparam r = o / NUM_INPUTS_P;
                assign vld_out_w[o] = vld_i[i] && arb_onehot[r];
                assign data_out_w[o]  = data_i[i];
            end

            for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_rdy_in
                logic [NUM_REQS-1:0] rdy_out_s;
                for (genvar r = 0; r < NUM_REQS; ++r) begin : g_r
                    localparam o = r * NUM_INPUTS_P + i;
                    assign rdy_out_s[r] = rdy_out_w[o];
                end
                assign rdy_i[i] = (NUM_INPUTS_P == 1) ? arb_vld : (| (rdy_out_s & arb_onehot));
            end

            assign arb_rdy = (| vld_i);

            for (genvar o = 0; o < NUM_OUTPUTS_P; ++o) begin : g_out_buf
                xrv_elastic_buffer #(
                    .DATA_WIDTH_P   (DATA_WIDTH_P),
                    .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
                    .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF)),
                    .LUTRAM         (`XM_TO_OUT_BUF_LUTRAM(OUT_BUF))
                ) out_buf (
                    .clk_i          (clk_i),
                    .rst_i          (rst_i),
                    .vld_i          (vld_out_w[o]),
                    .rdy_i          (rdy_out_w[o]),
                    .data_i         (data_out_w[o]),
                    .data_o         (data_o[o]),
                    .vld_o          (vld_o[o]),
                    .rdy_o          (rdy_o[o])
                );
            end

            for (genvar i = 0; i < NUM_INPUTS_P; ++i) begin : g_sel_out
                assign sel_o[i] = arb_index;
            end
        end

    end else begin : g_passthru

        // #Inputs == #Outputs

        for (genvar o = 0; o < NUM_OUTPUTS_P; ++o) begin : g_out_buf
            xrv_elastic_buffer #(
                .DATA_WIDTH_P   (DATA_WIDTH_P),
                .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
                .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF)),
                .LUTRAM         (`XM_TO_OUT_BUF_LUTRAM(OUT_BUF))
            ) out_buf (
                .clk_i          (clk_i),
                .rst_i          (rst_i),
                .vld_i          (vld_i[o]),
                .rdy_i          (rdy_i[o]),
                .data_i         (data_i[o]),
                .data_o         (data_o[o]),
                .vld_o          (vld_o[o]),
                .rdy_o          (rdy_o[o])
            );
            assign sel_o[o] = NUM_REQS_W'(0);
        end
    end

endmodule
`TRACING_ON
