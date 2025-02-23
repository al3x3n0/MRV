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

// rst_i all GPRs in debug mode
`ifdef SIMULATION
`ifndef NDEBUG
`define GPR_RESET
`endif
`endif

module xrv_vx_operands import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID   = "",
    parameter NUM_BANKS_P           = 4,
    parameter OUT_BUF               = 3,
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P                = "inv",
    parameter PC_WIDTH_P            = "inv",
    parameter NUM_THREADS_P         = "inv",
    parameter NUM_WARPS_P           = "inv",
    parameter WID_WIDTH_P           = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P           = `XM_CLOG2(NUM_THREADS_P),
    parameter UUID_WIDTH_P          = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P         = "inv",
    parameter PER_ISSUE_WARPS_P     = (NUM_WARPS_P / ISSUE_WIDTH_P),
    parameter ISSUE_WIS_P           = `XM_CLOG2(PER_ISSUE_WARPS_P),
    parameter ISSUE_WIS_WIDTH_P     = `XM_UP(ISSUE_WIS_P)
) (
    input wire              clk_i,
    input wire              rst_i,

`ifdef PERF_ENABLE
    output wire [VX_PERF_CTR_BITS-1:0] perf_stalls,
`endif

    xrv_vx_writeback_if.slave   writeback_if,
    xrv_vx_scoreboard_if.slave  scoreboard_if,
    xrv_vx_operands_if.master   operands_if
);
    `XM_UNUSED_SPARAM (INSTANCE_ID)
    localparam NUM_SRC_OPDS = 3;
    localparam REQ_SEL_BITS = `XM_CLOG2(NUM_SRC_OPDS);
    localparam REQ_SEL_WIDTH = `XM_UP(REQ_SEL_BITS);
    localparam BANK_SEL_BITS = `XM_CLOG2(NUM_BANKS_P);
    localparam BANK_SEL_WIDTH = `XM_UP(BANK_SEL_BITS);
    localparam PER_BANK_REGS = VX_NUM_REGS / NUM_BANKS_P;
    localparam META_DATAW = ISSUE_WIS_WIDTH_P + NUM_THREADS_P + PC_WIDTH_P + 1 + VX_EX_BITS + VX_INST_OP_BITS + VX_INST_ARGS_BITS + VX_NR_BITS + UUID_WIDTH_P;
    localparam REGS_DATAW = XLEN_P * NUM_THREADS_P;
    localparam DATAW = META_DATAW + NUM_SRC_OPDS * REGS_DATAW;
    localparam RAM_ADDRW = `XM_LOG2UP(VX_NUM_REGS * PER_ISSUE_WARPS_P);
    localparam PER_BANK_ADDR_WIDTH_LP = RAM_ADDRW - BANK_SEL_BITS;
    localparam XLEN_SIZE = XLEN_P / 8;
    localparam BYTEENW = NUM_THREADS_P * XLEN_SIZE;

    wire [NUM_SRC_OPDS-1:0] src_vld;
    wire [NUM_SRC_OPDS-1:0] req_vld_in, req_rdy_in;
    wire [NUM_SRC_OPDS-1:0][PER_BANK_ADDR_WIDTH_LP-1:0] req_data_in;
    wire [NUM_SRC_OPDS-1:0][BANK_SEL_WIDTH-1:0] req_bank_idx;

    wire [NUM_BANKS_P-1:0] gpr_rd_vld, gpr_rd_rdy;
    wire [NUM_BANKS_P-1:0] gpr_rd_vld_st1, gpr_rd_vld_st2;
    wire [NUM_BANKS_P-1:0][PER_BANK_ADDR_WIDTH_LP-1:0] gpr_rd_addr, gpr_rd_addr_st1;
    wire [NUM_BANKS_P-1:0][NUM_THREADS_P-1:0][XLEN_P-1:0] gpr_rd_data_st2;
    wire [NUM_BANKS_P-1:0][REQ_SEL_WIDTH-1:0] gpr_rd_req_idx, gpr_rd_req_idx_st1, gpr_rd_req_idx_st2;

    wire pipe_rdy_in;
    wire pipe_vld_st1, pipe_rdy_st1;
    wire pipe_vld_st2, pipe_rdy_st2;
    wire [META_DATAW-1:0] pipe_data, pipe_data_st1, pipe_data_st2;

    reg [NUM_SRC_OPDS-1:0][(NUM_THREADS_P * XLEN_P)-1:0] src_data_st2, src_data_m_st2;

    reg [NUM_SRC_OPDS-1:0] data_fetched_st1;

    reg has_collision_n;
    wire has_collision_st1;

    wire [NUM_SRC_OPDS-1:0][VX_NR_BITS-1:0] src_opds;
    assign src_opds = {scoreboard_if.data.rs3, scoreboard_if.data.rs2, scoreboard_if.data.rs1};

    for (genvar i = 0; i < NUM_SRC_OPDS; ++i) begin : g_req_data_in
        if (ISSUE_WIS_P != 0) begin : g_wis
            assign req_data_in[i] = {src_opds[i][VX_NR_BITS-1:BANK_SEL_BITS], scoreboard_if.data.wis};
        end else begin : g_no_wis
            assign req_data_in[i] = src_opds[i][VX_NR_BITS-1:BANK_SEL_BITS];
        end
    end

    for (genvar i = 0; i < NUM_SRC_OPDS; ++i) begin : g_req_bank_idx
        if (NUM_BANKS_P != 1) begin : g_multibanks
            assign req_bank_idx[i] = src_opds[i][BANK_SEL_BITS-1:0];
        end else begin : g_singlebank
            assign req_bank_idx[i] = '0;
        end
    end

    for (genvar i = 0; i < NUM_SRC_OPDS; ++i) begin : g_src_vld
        assign src_vld[i] = (src_opds[i] != 0) && ~data_fetched_st1[i];
    end

    assign req_vld_in = {NUM_SRC_OPDS{scoreboard_if.vld}} & src_vld;

    xrv_stream_xbar #(
        .NUM_INPUTS_P       (NUM_SRC_OPDS),
        .NUM_OUTPUTS_P      (NUM_BANKS_P),
        .DATA_WIDTH_P       (PER_BANK_ADDR_WIDTH_LP),
        .ARBITER_TYPE_P     ("P"), // use priority arbiter
        .PERF_CTR_BITS      (VX_PERF_CTR_BITS),
        .OUT_BUF            (0) // no output buffering
    ) req_xbar (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        `XM_UNUSED_PIN(collisions_o),
        .vld_i      (req_vld_in),
        .data_i     (req_data_in),
        .sel_i      (req_bank_idx),
        .rdy_i      (req_rdy_in),
        .vld_o      (gpr_rd_vld),
        .data_o     (gpr_rd_addr),
        .sel_o      (gpr_rd_req_idx),
        .rdy_o      (gpr_rd_rdy)
    );

    assign gpr_rd_rdy = {NUM_BANKS_P{pipe_rdy_in}};

    always @(*) begin
        has_collision_n = 0;
        for (integer i = 0; i < NUM_SRC_OPDS; ++i) begin
            for (integer j = 1; j < (NUM_SRC_OPDS-i); ++j) begin
                has_collision_n |= src_vld[i]
                                && src_vld[j+i]
                                && (req_bank_idx[i] == req_bank_idx[j+i]);
            end
        end
    end

    wire [NUM_SRC_OPDS-1:0] req_fire_in = req_vld_in & req_rdy_in;

    assign pipe_data = {
        scoreboard_if.data.wis,
        scoreboard_if.data.tmask,
        scoreboard_if.data.PC,
        scoreboard_if.data.wb,
        scoreboard_if.data.ex_type,
        scoreboard_if.data.op_type,
        scoreboard_if.data.op_args,
        scoreboard_if.data.rd,
        scoreboard_if.data.uuid
    };

    assign scoreboard_if.rdy = pipe_rdy_in && ~has_collision_n;

    wire pipe_fire_st1 = pipe_vld_st1 && pipe_rdy_st1;
    wire pipe_fire_st2 = pipe_vld_st2 && pipe_rdy_st2;

    xrv_pipe_buffer #(
        .DATA_WIDTH_P (NUM_BANKS_P + META_DATAW + 1 + NUM_BANKS_P * (PER_BANK_ADDR_WIDTH_LP + REQ_SEL_WIDTH))
    ) pipe_reg1 (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .vld_i      (scoreboard_if.vld),
        .rdy_i      (pipe_rdy_in),
        .data_i     ({gpr_rd_vld,     pipe_data,     has_collision_n,   gpr_rd_addr,     gpr_rd_req_idx}),
        .data_o     ({gpr_rd_vld_st1, pipe_data_st1, has_collision_st1, gpr_rd_addr_st1, gpr_rd_req_idx_st1}),
        .vld_o      (pipe_vld_st1),
        .rdy_o      (pipe_rdy_st1)
    );

    always @(posedge clk_i) begin
        if (rst_i || scoreboard_if.rdy) begin
            data_fetched_st1 <= 0;
        end else begin
            data_fetched_st1 <= data_fetched_st1 | req_fire_in;
        end
    end

    wire pipe_vld2_st1 = pipe_vld_st1 && ~has_collision_st1;

    xrv_pipe_buffer #(
        .DATA_WIDTH_P (NUM_BANKS_P * (1 + REQ_SEL_WIDTH) + META_DATAW)
    ) pipe_reg2 (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .vld_i      (pipe_vld2_st1),
        .rdy_i      (pipe_rdy_st1),
        .data_i     ({gpr_rd_vld_st1, gpr_rd_req_idx_st1, pipe_data_st1}),
        .data_o     ({gpr_rd_vld_st2, gpr_rd_req_idx_st2, pipe_data_st2}),
        .vld_o      (pipe_vld_st2),
        .rdy_o      (pipe_rdy_st2)
    );

    always @(*) begin
        src_data_m_st2 = src_data_st2;
        for (integer b = 0; b < NUM_BANKS_P; ++b) begin
            if (gpr_rd_vld_st2[b]) begin
                src_data_m_st2[gpr_rd_req_idx_st2[b]] = gpr_rd_data_st2[b];
            end
        end
    end

    always @(posedge clk_i) begin
        if (rst_i || pipe_fire_st2) begin
            src_data_st2 <= 0;
        end else begin
            src_data_st2 <= src_data_m_st2;
        end
    end

    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (DATAW),
        .SIZE_P         (`XM_TO_OUT_BUF_SIZE(OUT_BUF)),
        .OUT_REG        (`XM_TO_OUT_BUF_REG(OUT_BUF))
    ) out_buf (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .vld_i      (pipe_vld_st2),
        .rdy_i      (pipe_rdy_st2),
        .data_i     ({pipe_data_st2, src_data_m_st2}),
        .data_o     ({
            operands_if.data.wis,
            operands_if.data.tmask,
            operands_if.data.PC,
            operands_if.data.wb,
            operands_if.data.ex_type,
            operands_if.data.op_type,
            operands_if.data.op_args,
            operands_if.data.rd,
            operands_if.data.uuid,
            operands_if.data.rs3_data,
            operands_if.data.rs2_data,
            operands_if.data.rs1_data
        }),
        .vld_o      (operands_if.vld),
        .rdy_o      (operands_if.rdy)
    );

    wire [PER_BANK_ADDR_WIDTH_LP-1:0] gpr_wr_addr;
    if (ISSUE_WIS_P != 0) begin : g_gpr_wr_addr
        assign gpr_wr_addr = {writeback_if.data.rd[VX_NR_BITS-1:BANK_SEL_BITS], writeback_if.data.wis};
    end else begin : g_gpr_wr_addr_no_wis
        assign gpr_wr_addr = writeback_if.data.rd[VX_NR_BITS-1:BANK_SEL_BITS];
    end

    wire [BANK_SEL_WIDTH-1:0] gpr_wr_bank_idx;
    if (NUM_BANKS_P != 1) begin : g_gpr_wr_bank_idx
        assign gpr_wr_bank_idx = writeback_if.data.rd[BANK_SEL_BITS-1:0];
    end else begin : g_gpr_wr_bank_idx_0
        assign gpr_wr_bank_idx = '0;
    end

    for (genvar b = 0; b < NUM_BANKS_P; ++b) begin : g_gpr_rams
        wire gpr_wr_enabled;
        if (BANK_SEL_BITS != 0) begin : g_gpr_wr_enabled_multibanks
            assign gpr_wr_enabled = writeback_if.vld
                                 && (gpr_wr_bank_idx == BANK_SEL_BITS'(b));
        end else begin : g_gpr_wr_enabled
            assign gpr_wr_enabled = writeback_if.vld;
        end

        wire [BYTEENW-1:0] wren;
        for (genvar i = 0; i < NUM_THREADS_P; ++i) begin : g_wren
            assign wren[i*XLEN_SIZE+:XLEN_SIZE] = {XLEN_SIZE{writeback_if.data.tmask[i]}};
        end

        xrv_vx_dp_ram #(
            .DATAW (REGS_DATAW),
            .SIZE  (PER_BANK_REGS * PER_ISSUE_WARPS_P),
            .WRENW (BYTEENW),
         `ifdef GPR_RESET
            .RESET_RAM (1),
         `endif
            .OUT_REG (1),
            .RDW_MODE ("U")
        ) gpr_ram (
            .clk_i   (clk_i),
            .rst_i (rst_i),
            .read  (pipe_fire_st1),
            .wren  (wren),
            .write (gpr_wr_enabled),
            .waddr (gpr_wr_addr),
            .wdata (writeback_if.data.data),
            .raddr (gpr_rd_addr_st1[b]),
            .rdata (gpr_rd_data_st2[b])
        );
    end

`ifdef PERF_ENABLE
    reg [VX_PERF_CTR_BITS-1:0] collisions_r;
    always @(posedge clk_i) begin
        if (rst_i) begin
            collisions_r <= '0;
        end else begin
            collisions_r <= collisions_r + VX_PERF_CTR_BITS'(scoreboard_if.vld && pipe_rdy_in && has_collision_n);
        end
    end
    assign perf_stalls = collisions_r;
`endif

endmodule
