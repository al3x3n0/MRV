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

interface xrv_vx_decode_sched_if #(
    parameter NUM_WARPS_P   = "inv",
    parameter WID_WIDTH_P   = `XM_CLOG2(NUM_WARPS_P)
);

    wire                    vld;
    wire                    unlock;
    wire [WID_WIDTH_P-1:0]  wid;

    modport master (
        output vld,
        output unlock,
        output wid
    );

    modport slave (
        input vld,
        input unlock,
        input wid
    );

endinterface
