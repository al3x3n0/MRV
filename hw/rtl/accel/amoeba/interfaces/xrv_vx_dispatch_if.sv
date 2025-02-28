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

interface xrv_vx_dispatch_if import amoeba_gpu_pkg::*; #(
    parameter XLEN_P        = "inv",
    parameter PC_WIDTH_P    = XLEN_P - 1,
    parameter NUM_THREADS_P = "inv",
    parameter NUM_WARPS_P   = "inv",
    parameter TID_WIDTH_P   = `XM_LOG2UP(NUM_THREADS_P),
    parameter UUID_WIDTH_P  = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter ISSUE_WIDTH_P         = 1,
    parameter PER_ISSUE_WARPS_P     = (NUM_WARPS_P / ISSUE_WIDTH_P),
    parameter ISSUE_WIS_P           = `XM_CLOG2(PER_ISSUE_WARPS_P),
    parameter ISSUE_WIS_WIDTH_P     = `XM_UP(ISSUE_WIS_P)
);
    // warning: this layout should not be modified without updating xrv_vx_dispatch_unit!!!
    typedef struct packed {
        logic [UUID_WIDTH_P-1:0]            uuid;
        logic [ISSUE_WIS_WIDTH_P-1:0]       wis;
        logic [NUM_THREADS_P-1:0]           tmask;
        logic [PC_WIDTH_P-1:0]              PC;
        logic [VX_INST_ALU_BITS-1:0]        op_type;
        op_args_t                           op_args;
        logic                               wb;
        logic [VX_NR_BITS-1:0]              rd;
        logic [TID_WIDTH_P-1:0]             tid;
        logic [NUM_THREADS_P-1:0][XLEN_P-1:0] rs1_data;
        logic [NUM_THREADS_P-1:0][XLEN_P-1:0] rs2_data;
        logic [NUM_THREADS_P-1:0][XLEN_P-1:0] rs3_data;
    } data_t;

    logic  vld;
    data_t data;
    logic  rdy;

    modport master (
        output vld,
        output data,
        input  rdy
    );

    modport slave (
        input  vld,
        input  data,
        output rdy
    );

endinterface
