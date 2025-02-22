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

interface xrv_vx_schedule_if #(
    parameter PC_WIDTH_P        = "inv",
    parameter NUM_WARPS_P       = "inv",
    parameter NUM_THREADS_P     = "inv",
    parameter UUID_WIDTH_P      = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_P       = `XM_CLOG2(NUM_THREADS_P),
    parameter WID_WIDTH_P       = `XM_CLOG2(NUM_WARPS_P)
);

    typedef struct packed {
        logic [UUID_WIDTH_P-1:0]    uuid;
        logic [WID_WIDTH_P-1:0]     wid;
        logic [NUM_THREADS_P-1:0]   tmask;
        logic [PC_WIDTH_P-1:0]      PC;
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
