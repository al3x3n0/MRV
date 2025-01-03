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
module xrv_stream_omega #(
    parameter NUM_INPUTS_P      = 4,
    parameter NUM_OUTPUTS_P     = 4,
    parameter RADIX_P           = 2,
    parameter DATA_WIDTH_P      = 4,
    parameter ARBITER_TYPE_P    = "R",
    parameter OUT_BUF           = 0,
    parameter MAX_FANOUT        = 8,
    parameter PERF_CTR_BITS     = 32,
    parameter IN_WIDTH          = `XM_LOG2UP(NUM_INPUTS_P),
    parameter OUT_WIDTH         = `XM_LOG2UP(NUM_OUTPUTS_P)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                             clk_i,
    input logic                                             rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [NUM_INPUTS_P-1:0]                          vld_i,
    input logic [NUM_INPUTS_P-1:0][DATA_WIDTH_P-1:0]        data_i,
    input logic [NUM_INPUTS_P-1:0][OUT_WIDTH-1:0]           sel_i,
    output logic [NUM_INPUTS_P-1:0]                         rdy_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_OUTPUTS_P-1:0]                        vld_o,
    output logic [NUM_OUTPUTS_P-1:0][DATA_WIDTH_P-1:0]      data_o,
    output logic [NUM_OUTPUTS_P-1:0][IN_WIDTH-1:0]          sel_o,
    input  logic [NUM_OUTPUTS_P-1:0]                        rdy_o,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [PERF_CTR_BITS-1:0]                        collisions_o
);
    `STATIC_ASSERT (`XM_IS_POW2(RADIX_P), ("inavlid parameters"))

    ////////////////////////////////////////////////////////////////////////////////
    // If network size smaller than radix, simply use a crossbar.
    ////////////////////////////////////////////////////////////////////////////////
    if (NUM_INPUTS_P <= RADIX_P && NUM_OUTPUTS_P <= RADIX_P) begin : g_fallback
        xrv_stream_xbar #(
            .NUM_INPUTS_P       (NUM_INPUTS_P),
            .NUM_OUTPUTS_P      (NUM_OUTPUTS_P),
            .DATA_WIDTH_P              (DATA_WIDTH_P),
            .ARBITER_TYPE_P     (ARBITER_TYPE_P),
            .OUT_BUF            (OUT_BUF),
            .MAX_FANOUT         (MAX_FANOUT),
            .PERF_CTR_BITS      (PERF_CTR_BITS)
        ) xbar_switch (
            .clk_i,
            .rst_i,
            .vld_i,
            .data_i,
            .sel_i,
            .rdy_i,
            .vld_o,
            .data_o,
            .sel_o,
            .rdy_o,
            .collisions_o
        );
    end else begin : g_omega
        localparam RADIX_P_LG   = `XM_LOG2UP(RADIX_P);
        localparam N_INPUTS_M   = `XM_MAX(NUM_INPUTS_P, NUM_OUTPUTS_P);
        localparam N_INPUTS_LG  = `XM_CDIV(`XM_CLOG2(N_INPUTS_M), RADIX_P_LG);
        localparam N_INPUTS     = RADIX_P ** N_INPUTS_LG;
        localparam NUM_STAGES_LP   = `XM_LOG2UP(N_INPUTS) / RADIX_P_LG;
        localparam NUM_SWITCHES_LP = N_INPUTS / RADIX_P;

        typedef struct packed {
            logic [N_INPUTS_LG-1:0] sel_i;
            logic [DATA_WIDTH_P-1:0] data;
            logic [IN_WIDTH-1:0] sel_o;
        } omega_t;

        // Wires for internal connections between stages
        logic [NUM_STAGES_LP-1:0][NUM_SWITCHES_LP-1:0][RADIX_P-1:0]      switch_vld_i, switch_vld_o;
        omega_t [NUM_STAGES_LP-1:0][NUM_SWITCHES_LP-1:0][RADIX_P-1:0]   switch_data_i,  switch_data_o;
        logic [NUM_STAGES_LP-1:0][NUM_SWITCHES_LP-1:0][RADIX_P-1:0][RADIX_P_LG-1:0] switch_sel_i;
        logic [NUM_STAGES_LP-1:0][NUM_SWITCHES_LP-1:0][RADIX_P-1:0]      switch_rdy_i, switch_rdy_o;

        ////////////////////////////////////////////////////////////////////////////////
        // Connect inputs to first stage
        ////////////////////////////////////////////////////////////////////////////////
        for (genvar i = 0; i < N_INPUTS; ++i) begin : g_tie_inputs
            localparam DST_IDX = ((i << 1) | (i >> (N_INPUTS_LG-1))) & (N_INPUTS-1);
            localparam switch = DST_IDX / RADIX_P;
            localparam port = DST_IDX % RADIX_P;
            if (i < NUM_INPUTS_P) begin : g_vld
                assign switch_vld_i[0][switch][port] = vld_i[i];
                assign switch_data_i[0][switch][port] = '{
                    sel_i:  N_INPUTS_LG'(sel_i[i]),
                    data:    data_i[i],
                    sel_o: IN_WIDTH'(i)
                };
                assign rdy_i[i] = switch_rdy_i[0][switch][port];
            end else begin : g_padding
                assign switch_vld_i[0][switch][port] = 0;
                assign switch_data_i[0][switch][port] = 'x;
                `XM_UNUSED_VAR (switch_rdy_i[0][switch][port])
            end
        end

        ////////////////////////////////////////////////////////////////////////////////
        // Connect switch sel_i
        ////////////////////////////////////////////////////////////////////////////////
        for (genvar stage = 0; stage < NUM_STAGES_LP; ++stage) begin : g_sel_i
            for (genvar switch = 0; switch < NUM_SWITCHES_LP; ++switch) begin : g_switches
                for (genvar port = 0; port < RADIX_P; ++port) begin : g_ports
                    assign switch_sel_i[stage][switch][port] = switch_data_i[stage][switch][port].sel_i[(NUM_STAGES_LP-1-stage) * RADIX_P_LG +: RADIX_P_LG];
                end
            end
        end

        ////////////////////////////////////////////////////////////////////////////////
        // Connect internal stages
        ////////////////////////////////////////////////////////////////////////////////
        for (genvar stage = 0; stage < NUM_STAGES_LP-1; ++stage) begin : g_stages
            for (genvar switch = 0; switch < NUM_SWITCHES_LP; ++switch) begin : g_switches
                for (genvar port = 0; port < RADIX_P; port++) begin : g_ports
                    localparam lane = switch * RADIX_P + port;
                    localparam dst_lane = ((lane << 1) | (lane >> (N_INPUTS_LG-1))) & (N_INPUTS-1);
                    localparam dst_switch = dst_lane / RADIX_P;
                    localparam dst_port = dst_lane % RADIX_P;
                    assign switch_vld_i[stage+1][dst_switch][dst_port] = switch_vld_o[stage][switch][port];
                    assign switch_data_i[stage+1][dst_switch][dst_port] = switch_data_o[stage][switch][port];
                    assign switch_rdy_o[stage][switch][port] = switch_rdy_i[stage+1][dst_switch][dst_port];
                end
            end
        end

        ////////////////////////////////////////////////////////////////////////////////
        // Connect network switches
        ////////////////////////////////////////////////////////////////////////////////
        for (genvar switch = 0; switch < NUM_SWITCHES_LP; ++switch) begin : g_switches
            for (genvar stage = 0; stage < NUM_STAGES_LP; ++stage) begin : g_stages
                xrv_stream_xbar #(
                    .NUM_INPUTS_P       (RADIX_P),
                    .NUM_OUTPUTS_P      (RADIX_P),
                    .DATA_WIDTH_P       ($bits(omega_t)),
                    .ARBITER_TYPE_P     (ARBITER_TYPE_P),
                    .OUT_BUF            (OUT_BUF),
                    .MAX_FANOUT         (MAX_FANOUT),
                    .PERF_CTR_BITS      (PERF_CTR_BITS)
                 ) xbar_switch (
                    .clk_i              (clk_i),
                    .rst_i              (rst_i),
                    .vld_i              (switch_vld_i[stage][switch]),
                    .data_i             (switch_data_i[stage][switch]),
                    .sel_i              (switch_sel_i[stage][switch]),
                    .rdy_i              (switch_rdy_i[stage][switch]),
                    .vld_o              (switch_vld_o[stage][switch]),
                    .data_o             (switch_data_o[stage][switch]),
                    `XM_UNUSED_PIN      (sel_o),
                    .rdy_o              (switch_rdy_o[stage][switch]),
                    `XM_UNUSED_PIN      (collisions_o)
                );
            end
        end

        ////////////////////////////////////////////////////////////////////////////////
        // Connect outputs to last stage
        ////////////////////////////////////////////////////////////////////////////////
        for (genvar i = 0; i < N_INPUTS; ++i) begin : g_tie_outputs
            localparam switch = i / RADIX_P;
            localparam port = i % RADIX_P;
            if (i < NUM_OUTPUTS_P) begin : g_vld
                assign vld_o[i] = switch_vld_o[NUM_STAGES_LP-1][switch][port];
                assign data_o[i]  = switch_data_o[NUM_STAGES_LP-1][switch][port].data;
                assign sel_o[i]   = switch_data_o[NUM_STAGES_LP-1][switch][port].sel_o;
                assign switch_rdy_o[NUM_STAGES_LP-1][switch][port] = rdy_o[i];
            end else begin : g_padding
                `XM_UNUSED_VAR (switch_vld_o[NUM_STAGES_LP-1][switch][port])
                `XM_UNUSED_VAR (switch_data_o[NUM_STAGES_LP-1][switch][port])
                assign switch_rdy_o[NUM_STAGES_LP-1][switch][port] = 0;
            end
        end

        ////////////////////////////////////////////////////////////////////////////////
        // compute inputs collision
        // we have a collision when there exists a vld transfer with multiple input candicates
        // we count the unique duplicates each cycle.
        ////////////////////////////////////////////////////////////////////////////////

        reg [NUM_STAGES_LP-1:0][NUM_SWITCHES_LP-1:0][RADIX_P-1:0] per_cycle_collision, per_cycle_collision_r;
        logic [`XM_CLOG2(NUM_STAGES_LP*NUM_SWITCHES_LP*RADIX_P+1)-1:0] collision_count;
        reg [PERF_CTR_BITS-1:0] collisions_r;

        always_comb begin
            per_cycle_collision = 0;
            for (integer stage = 0; stage < NUM_STAGES_LP; ++stage) begin
                for (integer switch = 0; switch < NUM_SWITCHES_LP; ++switch) begin
                    for (integer port_a = 0; port_a < RADIX_P; ++port_a) begin
                        for (integer port_b = port_a + 1; port_b < RADIX_P; ++port_b) begin
                            per_cycle_collision[stage][switch][port_a] |= switch_vld_i[stage][switch][port_a]
                                                                       && switch_vld_i[stage][switch][port_b]
                                                                       && (switch_sel_i[stage][switch][port_a] == switch_sel_i[stage][switch][port_b])
                                                                       && (switch_rdy_i[stage][switch][port_a] | switch_rdy_i[stage][switch][port_b]);
                        end
                    end
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
    end

endmodule
`TRACING_ON
