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


module xrv_cache_data #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                    = 64,
    parameter MEM_ADDR_WIDTH_P          = XLEN_P,
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CACHE_DEFAULT_PARAMS,
    ////////////////////////////////////////////////////////////////////////////////
    // Enable cache writeable
    ////////////////////////////////////////////////////////////////////////////////
    parameter IS_WRITEABLE_P            = 1,
    ////////////////////////////////////////////////////////////////////////////////
    // Enable cache wrback
    ////////////////////////////////////////////////////////////////////////////////
    parameter HAS_WRITEBACK_P           = 0,
    ////////////////////////////////////////////////////////////////////////////////
    // Enable dirty bytes on wrback
    ////////////////////////////////////////////////////////////////////////////////
    parameter HAS_DIRTY_BYTES_P         = 0,
    ////////////////////////////////////////////////////////////////////////////////
    `XRV_CACHE_LOCALPARAMS
    ////////////////////////////////////////////////////////////////////////////////

) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        clk_i,
    input  logic                                        rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic                                        stall,
    input  logic                                        init_i,
    input  logic                                        do_fill_i,
    input  logic                                        do_flush_i,
    input  logic                                        do_rd_i,
    input  logic                                        do_wr_i,
    input  logic [CACHE_LINE_SEL_BITS_LP-1:0]           line_idx_i,
    input  logic [CACHE_WAY_SEL_WIDTH_LP-1:0]           evict_way_i,
    input  logic [NUM_WAYS_P-1:0]                       tag_matches_i,
    input  logic [CACHE_WORDS_PER_LINE_LP-1:0][CACHE_WORD_WIDTH_LP-1:0] fill_data_i,
    input  logic [CACHE_WORD_WIDTH_LP-1:0]              wr_word_i,
    input  logic [WORD_SIZE_P-1:0]                      wr_be_i,
    input  logic [`XM_UP(CACHE_WORD_SEL_BITS_LP)-1:0]   word_idx_i,
    input  logic [CACHE_WAY_SEL_WIDTH_LP-1:0]           way_idx_i,
    output logic [CACHE_LINE_WIDTH_LP-1:0]              rd_data_o,
    output logic [LINE_SIZE_P-1:0]                      evict_be_o
);
    `XM_UNUSED_VAR (stall)

    logic [CACHE_WORDS_PER_LINE_LP-1:0][WORD_SIZE_P-1:0] wr_mask;
    for (genvar i = 0; i < CACHE_WORDS_PER_LINE_LP; ++i) begin : g_wr_mask
        wire word_en = (CACHE_WORDS_PER_LINE_LP == 1) || (word_idx_i == i);
        assign wr_mask[i] = wr_be_i & {WORD_SIZE_P{word_en}};
    end

    if (HAS_DIRTY_BYTES_P != 0) begin : g_dirty_bytes

        logic [NUM_WAYS_P-1:0][LINE_SIZE_P-1:0] be_rdata;

        for (genvar i = 0; i < NUM_WAYS_P; ++i) begin : g_be_store
            wire [LINE_SIZE_P-1:0] be_wdata = {LINE_SIZE_P{do_wr_i}}; // only asserted on wrs
            wire [LINE_SIZE_P-1:0] be_wren = {LINE_SIZE_P{init_i || do_fill_i || do_flush_i}} | wr_mask;
            wire be_wr = ((do_fill_i || do_flush_i) && ((NUM_WAYS_P == 1) || (evict_way_i == i)))
                             || (do_wr_i && tag_matches_i[i])
                             || init_i;
            wire be_rd  = do_fill_i || do_flush_i;

            xrv_mem_1rw_wren_bitmask_sync #(
                .DATA_WIDTH_P       (LINE_SIZE_P),
                .DEPTH_P            (CACHE_LINES_PER_BANK_LP)//,
                //.RDW_MODE           ("R")
            ) be_store (
                .clk_i              (clk_i),
                .rst_i              (rst_i),
                .do_rd_i            (be_rd),
                .do_wr_i            (be_wr),
                .wr_mask_i          (be_wren),
                .addr_i             (line_idx_i),
                .wr_data_i          (be_wdata),
                .rd_data_o          (be_rdata[i])
            );
        end

        assign evict_be_o = be_rdata[way_idx_i];

    end else begin : g_no_dirty_bytes
        `XM_UNUSED_VAR (init_i)
        `XM_UNUSED_VAR (do_flush_i)
        assign evict_be_o = '1; // update whole line
    end

    logic [NUM_WAYS_P-1:0][CACHE_WORDS_PER_LINE_LP-1:0][CACHE_WORD_WIDTH_LP-1:0] line_rdata;

    for (genvar i = 0; i < NUM_WAYS_P; ++i) begin : g_data_store

        localparam WRENW = IS_WRITEABLE_P ? LINE_SIZE_P : 1;

        logic [CACHE_WORDS_PER_LINE_LP-1:0][CACHE_WORD_WIDTH_LP-1:0] line_wdata;
        logic [WRENW-1:0] line_wren;

        if (IS_WRITEABLE_P) begin : g_wren
            assign line_wdata = do_fill_i ? fill_data_i : {CACHE_WORDS_PER_LINE_LP{wr_word_i}};
            assign line_wren  = {LINE_SIZE_P{do_fill_i}} | wr_mask;
        end else begin : g_no_wren
            `XM_UNUSED_VAR (wr_word_i)
            `XM_UNUSED_VAR (wr_mask)
            assign line_wdata = fill_data_i;
            assign line_wren  = 1'b1;
        end

        wire line_wr = (do_fill_i && ((NUM_WAYS_P == 1) || (evict_way_i == i)))
                       || (do_wr_i && tag_matches_i[i] && IS_WRITEABLE_P);

        wire line_rd = do_rd_i || ((do_fill_i || do_flush_i) && HAS_WRITEBACK_P);

        xrv_mem_1rw_wren_bytemask_sync #(
            .DATA_WIDTH_P       (CACHE_LINE_WIDTH_LP),
            .DEPTH_P            (CACHE_LINES_PER_BANK_LP)
            //.RDW_MODE           ("R")
        ) data_store (
            .clk_i              (clk_i),
            .rst_i              (rst_i),
            .do_rd_i            (line_rd),
            .do_wr_i            (line_wr),
            .wr_mask_i          (line_wren),
            .addr_i             (line_idx_i),
            .wr_data_i          (line_wdata),
            .rd_data_o          (line_rdata[i])
        );
    end

    assign rd_data_o = line_rdata[way_idx_i];

endmodule
