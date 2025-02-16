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

`include "xrv_vx_define.vh"

interface xrv_vx_execute_if import xrv_vx_gpu_pkg::*; #(
    parameter XLEN_P            = "inv",
    parameter PC_WIDTH_P        = XLEN_P,
    parameter NUM_WARPS_P       = "inv",
    parameter NUM_THREADS_P     = "inv",
    parameter WID_WIDTH_P       = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_LP      = `XM_CLOG2(NUM_THREADS_P),
    parameter NUM_LANES_P       = NUM_THREADS_P,
    parameter UUID_WIDTH_P      = 1
);
    typedef struct packed {
        logic [UUID_WIDTH_P-1:0]        uuid;
        logic [WID_WIDTH_P-1:0]         wid;
        logic [NUM_LANES_P-1:0]         tmask;
        logic [PC_WIDTH_P-1:0]          PC;
        logic [`INST_ALU_BITS-1:0]      op_type;
        op_args_t                       op_args;
        logic                           wb;
        logic [`NR_BITS-1:0]            rd;
        logic [TID_WIDTH_LP-1:0]        tid;
        logic [NUM_LANES_P-1:0][XLEN_P-1:0] rs1_data;
        logic [NUM_LANES_P-1:0][XLEN_P-1:0] rs2_data;
        logic [NUM_LANES_P-1:0][XLEN_P-1:0] rs3_data;
    } data_t;

    logic  valid;
    data_t data;
    logic  ready;

    modport master (
        output valid,
        output data,
        input  ready
    );

    modport slave (
        input  valid,
        input  data,
        output ready
    );

endinterface
