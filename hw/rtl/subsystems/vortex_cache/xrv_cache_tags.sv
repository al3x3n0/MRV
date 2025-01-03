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


module xrv_cache_tags #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                    = 64,
    parameter MEM_ADDR_WIDTH_P          = XLEN_P,
    ////////////////////////////////////////////////////////////////////////////////
    // Size of cache in bytes
    ////////////////////////////////////////////////////////////////////////////////
    parameter CACHE_SIZE_P              = 65536,
    ////////////////////////////////////////////////////////////////////////////////
    // Number of Word requests per cycle
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_REQS_P                = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Size of line inside a bank in bytes
    ////////////////////////////////////////////////////////////////////////////////
    parameter LINE_SIZE_P               = 16,
    ////////////////////////////////////////////////////////////////////////////////
    // Number of banks
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_BANKS_P               = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Number of associative ways
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_WAYS_P                = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Size of a word in bytes
    ////////////////////////////////////////////////////////////////////////////////
    parameter WORD_SIZE_P               = 4,
    ////////////////////////////////////////////////////////////////////////////////
    // Enable cache writeback
    ////////////////////////////////////////////////////////////////////////////////
    parameter HAS_WRITEBACK_P           = 0,
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CACHE_LOCALPARAMS
    ////////////////////////////////////////////////////////////////////////////////

) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                     clk_i,
    input logic                                     rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                     do_init_i,
    input logic                                     do_flush_i,
    input logic                                     do_fill_i,
    input logic                                     do_rd_i,
    input logic                                     do_wr_i,
    input logic [CACHE_LINE_SEL_BITS_LP-1:0]        line_idx_i,
    input logic [CACHE_TAG_SEL_BITS_LP-1:0]         line_tag_i,
    input logic [CACHE_WAY_SEL_WIDTH_LP-1:0]        evict_way_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [NUM_WAYS_P-1:0]                   tag_matches_o,
    output logic                                    evict_dirty_o,
    output logic [CACHE_TAG_SEL_BITS_LP-1:0]        evict_tag_o
);
    ////////////////////////////////////////////////////////////////////////////////
    // Valid + Dirty + Tag
    ////////////////////////////////////////////////////////////////////////////////
    localparam TAG_WIDTH_LP = 1 + HAS_WRITEBACK_P + CACHE_TAG_SEL_BITS_LP;

    logic [NUM_WAYS_P-1:0][CACHE_TAG_SEL_BITS_LP-1:0] read_tag;
    logic [NUM_WAYS_P-1:0] read_valid;
    logic [NUM_WAYS_P-1:0] read_dirty;

    if (HAS_WRITEBACK_P) begin : g_evict_tag_wb
        assign evict_dirty_o = read_dirty[evict_way_i];
        assign evict_tag_o = read_tag[evict_way_i];
    end else begin : g_evict_tag_wt
        `XM_UNUSED_VAR (read_dirty)
        assign evict_dirty_o = 1'b0;
        assign evict_tag_o = '0;
    end

    for (genvar i = 0; i < NUM_WAYS_P; ++i) begin : g_tag_store
        logic way_en   = (NUM_WAYS_P == 1) || (evict_way_i == i);
        logic do_init  = do_init_i; // init all ways
        logic do_fill  = do_fill_i && way_en;
        logic do_flush = do_flush_i && (!HAS_WRITEBACK_P || way_en); // flush the whole line in writethrough mode
        logic do_write = HAS_WRITEBACK_P && do_wr_i && tag_matches_o[i]; // only write on tag hit

        logic line_read  = do_rd_i || do_wr_i || (HAS_WRITEBACK_P && (do_fill_i || do_flush_i));
        logic line_write = do_init || do_fill || do_flush_i || do_write;
        logic line_valid = do_fill_i || do_wr_i;

        logic [TAG_WIDTH_LP-1:0] line_wdata;
        logic [TAG_WIDTH_LP-1:0] line_rdata;

        if (HAS_WRITEBACK_P) begin : g_wdata
            assign line_wdata = {line_valid, do_wr_i, line_tag_i};
            assign {read_valid[i], read_dirty[i], read_tag[i]} = line_rdata;
        end else begin : g_wdata
            assign line_wdata = {line_valid, line_tag_i};
            assign {read_valid[i], read_tag[i]} = line_rdata;
            assign read_dirty[i] = 1'b0;
        end

        xrv_mem_1rw #(
            .DATA_WIDTH_P       (TAG_WIDTH_LP),
            .DEPTH_P            (CACHE_LINES_PER_BANK_LP)
            // FIXME .RDW_MODE           ("W")
            //.RADDR_REG        (1)
        ) tag_store_i (
            .clk_i          (clk_i),
            .rst_i          (rst_i),
            //FIXME .do_rd_i        (line_read),
            .do_wr_i        (line_write),
            .addr_i         (line_idx_i),
            .wr_data_i      (line_wdata),
            .rd_data_o      (line_rdata)
        );
    end

    for (genvar i = 0; i < NUM_WAYS_P; ++i) begin : g_tag_matches
        assign tag_matches_o[i] = read_valid[i] && (line_tag_i == read_tag[i]);
    end

endmodule
