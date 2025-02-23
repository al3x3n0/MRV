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

interface xrv_vx_fetch_if #(
    parameter XLEN_P            = "inv",
    parameter PC_WIDTH_P        = XLEN_P,
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_WARPS_P       = "inv",
    parameter NUM_THREADS_P     = "inv",
    parameter WID_WIDTH_P       = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P       = `XM_CLOG2(NUM_THREADS_P),
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P      = "inv"
);

    typedef struct packed {
        logic [UUID_WIDTH_P-1:0]    uuid;
        logic [WID_WIDTH_P-1:0]     wid;
        logic [NUM_THREADS_P-1:0]   tmask;
        logic [PC_WIDTH_P-1:0]      PC;
        logic [31:0]                instr;
    } data_t;

    logic  vld;
    data_t data;
    logic  rdy;
`ifndef L1_ENABLE
    logic [NUM_WARPS_P-1:0] ibuf_pop;
`endif

    modport master (
        output vld,
        output data,
        input  rdy
    `ifndef L1_ENABLE
        , input ibuf_pop
    `endif
    );

    modport slave (
        input  vld,
        input  data,
        output rdy
    `ifndef L1_ENABLE
        , output ibuf_pop
    `endif
    );

endinterface
