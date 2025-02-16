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

`include "xrv_vortex_define.vh"

interface xra_vx_execute_if #(
    parameter XLEN_P            = 64,
    parameter VX_NUM_THREADS_P     = 32,
    parameter RF_ADDR_WIDTH_P   = 5
);
    typedef struct packed {
        logic [VX_UUID_WIDTH_P-1:0]     uuid;
        logic [VX_WID_WIDTH_P-1:0]      wid;
        logic [VX_NUM_THREADS_P-1:0]    tmask;
        logic [VX_PC_WIDTH_P-1:0]       PC;
        logic [`INST_ALU_BITS-1:0]      op_type;
        op_args_t                       op_args;
        logic                           wb;
        logic [RF_ADDR_WIDTH_P-1:0]     rd;
        logic [VX_TID_WIDTH_P-1:0]      tid;
        logic [XLEN_P-1:0]              rs1_data;
        logic [XLEN_P-1:0]              rs2_data;
        logic [XLEN_P-1:0]              rs3_data;
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
