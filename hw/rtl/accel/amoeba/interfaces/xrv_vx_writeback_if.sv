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

interface xrv_vx_writeback_if import amoeba_gpu_pkg::*; #(
    parameter XLEN_P            = "inv",
    parameter PC_WIDTH_P        = XLEN_P,
    parameter UUID_WIDTH_P      = 0
) ();

    typedef struct packed {
        logic [UUID_WIDTH_P-1:0]                uuid;
        logic [ISSUE_WIS_W-1:0]                 wis;
        logic [NUM_THREADS_P-1:0]               tmask;
        logic [PC_WIDTH_P-1:0]                  PC;
        logic [VX_NR_BITS-1:0]                  rd;
        logic [NUM_THREADS_P-1:0][XLEN_P-1:0]   data;
    } data_t;

    logic  valid;
    data_t data;

    modport master (
        output valid,
        output data
    );

    modport slave (
        input valid,
        input data
    );

endinterface
