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

module xrv_vx_split_join import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID   = "",
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_THREADS_P         = "inv",
    parameter NUM_WARPS_P           = "inv",
    parameter PC_WIDTH_P            = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_P           = `XM_CLOG2(NUM_THREADS_P),
    parameter WID_WIDTH_P           = `XM_CLOG2(NUM_WARPS_P),
    ////////////////////////////////////////////////////////////////////////////////
    parameter DV_STACK_SIZE_P       = `XM_UP(NUM_THREADS_P-1),
    parameter DV_STACK_SIZE_WIDTH_P = `XM_UP(`XM_CLOG2(DV_STACK_SIZE_P))
) (
    input  wire                         clk_i,
    input  wire                         rst_i,
    input  wire                         vld,
    input  wire [WID_WIDTH_P-1:0]       wid,
    input logic                     split_vld,
    input logic                     split_is_dvg,
    input logic [NUM_THREADS_P-1:0] split_then_tmask,
    input logic [NUM_THREADS_P-1:0] split_else_tmask,
    input logic [PC_WIDTH_P-1:0]    split_next_pc,
    input logic                     sjoin_vld,
    input logic [DV_STACK_SIZE_WIDTH_P-1:0] sjoin_stack_ptr,
    output wire                         join_vld,
    output wire                         join_is_dvg,
    output wire                         join_is_else,
    output wire [WID_WIDTH_P-1:0]       join_wid,
    output wire [NUM_THREADS_P-1:0]     join_tmask,
    output wire [PC_WIDTH_P-1:0]        join_pc,
    input  wire [WID_WIDTH_P-1:0]       stack_wid,
    output wire [DV_STACK_SIZE_WIDTH_P-1:0]   stack_ptr
);
    `XM_UNUSED_SPARAM (INSTANCE_ID)

    wire [(NUM_THREADS_P+PC_WIDTH_P)-1:0] ipdom_data [NUM_WARPS_P-1:0];
    wire [DV_STACK_SIZE_WIDTH_P-1:0] ipdom_q_ptr [NUM_WARPS_P-1:0];
    wire ipdom_set [NUM_WARPS_P-1:0];

    wire [(NUM_THREADS_P+PC_WIDTH_P)-1:0] ipdom_q0 = {split_then_tmask | split_else_tmask, PC_WIDTH_P'(0)};
    wire [(NUM_THREADS_P+PC_WIDTH_P)-1:0] ipdom_q1 = {split_else_tmask, split_next_pc};

    wire sjoin_is_dvg = (sjoin_stack_ptr != ipdom_q_ptr[wid]);

    wire ipdom_push = vld && split_vld && split_is_dvg;
    wire ipdom_pop = vld && sjoin_vld && sjoin_is_dvg;

    for (genvar i = 0; i < NUM_WARPS_P; ++i) begin : g_ipdom_stacks
        xrv_vx_ipdom_stack #(
            .WIDTH      (NUM_THREADS_P+PC_WIDTH_P),
            .DEPTH      (DV_STACK_SIZE_P)
        ) ipdom_stack (
            .clk_i      (clk_i),
            .rst_i      (rst_i),
            .q0         (ipdom_q0),
            .q1         (ipdom_q1),
            .d          (ipdom_data[i]),
            .d_set      (ipdom_set[i]),
            .q_ptr      (ipdom_q_ptr[i]),
            .push       (ipdom_push && (i == wid)),
            .pop        (ipdom_pop && (i == wid)),
            `XM_UNUSED_PIN (empty),
            `XM_UNUSED_PIN (full)
        );
    end

    xrv_pipe_register #(
        .DATA_WIDTH_P   (1 + 1 + 1 + WID_WIDTH_P + NUM_THREADS_P + PC_WIDTH_P),
        .DEPTH_P        (1),
        .RESET_WIDTH_P  (1)
    ) pipe_reg (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .en_i       (1'b1),
        .data_i     ({vld && sjoin_vld, sjoin_is_dvg, ipdom_set[wid], wid, ipdom_data[wid]}),
        .data_o     ({join_vld, join_is_dvg, join_is_else, join_wid, {join_tmask, join_pc}})
    );

    assign stack_ptr = ipdom_q_ptr[stack_wid];

endmodule
