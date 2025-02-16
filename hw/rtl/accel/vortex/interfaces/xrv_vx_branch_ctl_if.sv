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


interface xrv_vx_branch_ctl_if #(
    parameter PC_WIDTH_P    = "inv",
    parameter NUM_WARPS_P   = "inv",
    parameter WID_WIDTH_P   = `XM_CLOG2(NUM_WARPS_P)
) ();

    wire                    valid;
    wire [WID_WIDTH_P-1:0]  wid;
    wire                    taken;
    wire [PC_WIDTH_P-1:0]   dest;

    modport master (
        output valid,
        output wid,
        output taken,
        output dest
    );

    modport slave (
        input valid,
        input wid,
        input taken,
        input dest
    );

endinterface
