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

interface xrv_vx_ibuffer_if import amoeba_gpu_pkg::*; #(
    parameter XLEN_P        = "inv",
    parameter PC_WIDTH_P    = XLEN_P - 1,
    parameter NUM_THREADS_P = "inv",
    parameter UUID_WIDTH_P  = "inv"
);

    typedef struct packed {
        logic [UUID_WIDTH_P-1:0]    uuid;
        logic [NUM_THREADS_P-1:0]   tmask;
        logic [PC_WIDTH_P-1:0]      PC;
        logic [VX_EX_BITS-1:0]      ex_type;
        logic [VX_INST_OP_BITS-1:0] op_type;
        op_args_t                   op_args;
        logic                       wb;
        logic [VX_NR_BITS-1:0]      rd;
        logic [VX_NR_BITS-1:0]      rs1;
        logic [VX_NR_BITS-1:0]      rs2;
        logic [VX_NR_BITS-1:0]      rs3;
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
