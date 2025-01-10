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


// Fast PLRU encoder and decoder utility
// Adapted from BaseJump STL: http://bjump.org/data_out.html


module plru_decoder #(
    parameter NUM_WAYS      = 1,
    parameter WAY_IDX_BITS  = $clog2(NUM_WAYS),
    parameter WAY_IDX_WIDTH = `XM_UP(WAY_IDX_BITS)
) (
    input  logic [WAY_IDX_WIDTH-1:0]    way_idx,
    output logic [`XM_UP(NUM_WAYS-1)-1:0] lru_data,
    output logic [`XM_UP(NUM_WAYS-1)-1:0] lru_mask
);
    if (NUM_WAYS > 1) begin : g_dec
        logic [`XM_UP(NUM_WAYS-1)-1:0] data;
    `IGNORE_UNOPTFLAT_BEGIN
        logic [`XM_UP(NUM_WAYS-1)-1:0] mask;
    `IGNORE_UNOPTFLAT_END
        for (genvar i = 0; i < NUM_WAYS-1; ++i) begin : g_i
            if (i == 0) begin : g_i_0
                assign mask[i] = 1'b1;
            end else if (i % 2 == 1) begin : g_i_odd
                assign mask[i] = mask[(i-1)/2] & ~way_idx[WAY_IDX_BITS-$clog2(i+2)+1];
            end else begin : g_i_even
                assign mask[i] = mask[(i-2)/2] & way_idx[WAY_IDX_BITS-$clog2(i+2)+1];
            end
            assign data[i] = ~way_idx[WAY_IDX_BITS-$clog2(i+2)];
        end
        assign lru_data = data;
        assign lru_mask = mask;
    end else begin : g_no_dec
        `XM_UNUSED_VAR (way_idx)
        assign lru_data = '0;
        assign lru_mask = '0;
    end

endmodule

module plru_encoder #(
    parameter NUM_WAYS      = 1,
    parameter WAY_IDX_BITS  = $clog2(NUM_WAYS),
    parameter WAY_IDX_WIDTH = `XM_UP(WAY_IDX_BITS)
) (
    input logic [`XM_UP(NUM_WAYS-1)-1:0] lru_in,
    output logic [WAY_IDX_WIDTH-1:0] way_idx
);
    if (NUM_WAYS > 1) begin : g_enc
        logic [WAY_IDX_BITS-1:0] tmp;
        for (genvar i = 0; i < WAY_IDX_BITS; ++i) begin : g_i
            if (i == 0) begin : g_i_0
                assign tmp[WAY_IDX_WIDTH-1] = lru_in[0];
            end else begin : g_i_n
                xrv_mux #(
                    .N (2**i)
                ) mux (
                    .data_in  (lru_in[((2**i)-1)+:(2**i)]),
                    .sel_in   (tmp[WAY_IDX_BITS-1-:i]),
                    .data_out (tmp[WAY_IDX_BITS-1-i])
                );
            end
        end
        assign way_idx = tmp;
    end else begin : g_no_enc
        `XM_UNUSED_VAR (lru_in)
        assign way_idx = '0;
    end

endmodule

module xrv_cache_repl #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                    = 64,
    parameter MEM_ADDR_WIDTH_P          = XLEN_P,
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CACHE_DEFAULT_PARAMS,
    `XRV_CACHE_LOCALPARAMS,
    parameter REPL_POLICY = `CACHE_REPL_CYCLIC
) (
    input logic clk_i,
    input logic rst_i,
    input logic stall,
    input logic hit_vld,
    input logic [CACHE_LINE_SEL_BITS_LP-1:0] hit_line,
    input logic [CACHE_WAY_SEL_WIDTH_LP-1:0] hit_way,
    input logic repl_vld,
    input logic [CACHE_LINE_SEL_BITS_LP-1:0] repl_line,
    output logic [CACHE_WAY_SEL_WIDTH_LP-1:0] repl_way
);
    localparam WAY_SEL_WIDTH = CACHE_WAY_SEL_WIDTH_LP;
    `XM_UNUSED_VAR (stall)

    if (NUM_WAYS_P > 1) begin : g_enable
        if (REPL_POLICY == `CACHE_REPL_PLRU) begin : g_plru
            // Pseudo Least Recently Used replacement policy
            localparam LRU_WIDTH = `XM_UP(NUM_WAYS_P-1);

            logic [LRU_WIDTH-1:0] plru_rdata;
            logic [LRU_WIDTH-1:0] plru_wdata;
            logic [LRU_WIDTH-1:0] plru_wmask;

            xrv_dp_ram #(
                .DATAW      (LRU_WIDTH),
                .SIZE       (CACHE_LINES_PER_BANK_LP),
                .WRENW      (LRU_WIDTH),
                .RDW_MODE   ("R"),
                .RADDR_REG  (1)
            ) plru_store (
                .clk_i        (clk_i),
                .rst_i      (rst_i),
                .read       (repl_vld),
                .write      (hit_vld),
                .wren       (plru_wmask),
                .waddr      (hit_line),
                .raddr      (repl_line),
                .wdata      (plru_wdata),
                .rdata      (plru_rdata)
            );

            plru_decoder #(
                .NUM_WAYS   (NUM_WAYS_P)
            ) plru_dec (
                .way_idx    (hit_way),
                .lru_data   (plru_wdata),
                .lru_mask   (plru_wmask)
            );

            plru_encoder #(
                .NUM_WAYS   (NUM_WAYS_P)
            ) plru_enc (
                .lru_in     (plru_rdata),
                .way_idx    (repl_way)
            );

        end else if (REPL_POLICY == `CACHE_REPL_CYCLIC) begin : g_cyclic
            // Cyclic replacement policy
            `XM_UNUSED_VAR (hit_vld)
            `XM_UNUSED_VAR (hit_line)
            `XM_UNUSED_VAR (hit_way)

            logic [WAY_SEL_WIDTH-1:0] ctr_rdata;
            wire [WAY_SEL_WIDTH-1:0] ctr_wdata = ctr_rdata + 1;

            xrv_mem_1rw #(
                .DATA_WIDTH_P       (WAY_SEL_WIDTH),
                .DEPTH_P            (CACHE_LINES_PER_BANK_LP)//,
                // FIXME .RDW_MODE           ("R")
            ) ctr_store (
                .clk_i              (clk_i),
                .rst_i              (rst_i),
                .do_wr_i            (repl_vld),
                .addr_i             (repl_line),
                .wr_data_i          (ctr_wdata),
                .rd_data_o          (ctr_rdata)
            );

            assign repl_way = ctr_rdata;
        end else begin : g_random
            // Random replacement policy
            `XM_UNUSED_VAR (hit_vld)
            `XM_UNUSED_VAR (hit_line)
            `XM_UNUSED_VAR (hit_way)
            `XM_UNUSED_VAR (repl_vld)
            `XM_UNUSED_VAR (repl_line)
            reg [WAY_SEL_WIDTH-1:0] victim_idx;
            always @(posedge clk_i) begin
                if (rst_i) begin
                    victim_idx <= 0;
                end else if (~stall) begin
                    victim_idx <= victim_idx + 1;
                end
            end
            assign repl_way = victim_idx;
        end
    end else begin : g_disable
        `XM_UNUSED_VAR (clk_i)
        `XM_UNUSED_VAR (rst_i)
        `XM_UNUSED_VAR (hit_vld)
        `XM_UNUSED_VAR (hit_line)
        `XM_UNUSED_VAR (hit_way)
        `XM_UNUSED_VAR (repl_vld)
        `XM_UNUSED_VAR (repl_line)
        assign repl_way = 1'b0;
    end

endmodule
