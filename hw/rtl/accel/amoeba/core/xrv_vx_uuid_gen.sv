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

module xrv_vx_uuid_gen import amoeba_gpu_pkg::*; #(
    parameter CORE_ID       = 0,
    parameter UUID_WIDTH_P  = 48,
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_WARPS_P   = 4,
    parameter WID_WIDTH_P   = `XM_CLOG2(NUM_WARPS_P)
) (
    input wire clk_i,
    input wire rst_i,
    input wire incr,
    input wire [WID_WIDTH_P-1:0] wid,
    output wire [UUID_WIDTH_P-1:0] uuid
);
    localparam GNW_WIDTH_LP = UUID_WIDTH_P - 32;
    reg [31:0] uuid_cntrs [0:NUM_WARPS_P-1];
    reg [NUM_WARPS_P-1:0] has_uuid_cntrs;

    always @(posedge clk_i) begin
        if (rst_i) begin
            has_uuid_cntrs <= '0;
        end else if (incr) begin
            has_uuid_cntrs[wid] <= 1;
        end
        if (incr) begin
            uuid_cntrs[wid] <= has_uuid_cntrs[wid] ? (uuid_cntrs[wid] + 1) : 1;
        end
    end

    wire [GNW_WIDTH_LP-1:0] g_wid = (GNW_WIDTH_LP'(CORE_ID) << WID_WIDTH_P) + GNW_WIDTH_LP'(wid);
    assign uuid = {g_wid, (has_uuid_cntrs[wid] ? uuid_cntrs[wid] : 0)};

endmodule
