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

module xrv_vx_dcr_data import amoeba_gpu_pkg::*; #(
    parameter XLEN_P = 64
)(
    input wire              clk_i,
    input wire              rst_i,

    // Inputs
    xrv_vx_dcr_bus_if.slave     dcr_bus_if,

    // Outputs
    output xrv_vx_base_dcrs_if  base_dcrs
);

    `XM_UNUSED_VAR (rst_i)

    logic [XLEN_P-1:0]  dcrs_startup_addr;
    logic [XLEN_P-1:0]  dcrs_startup_arg;
    logic [7:0]         dcrs_mpm_class;


    always @(posedge clk_i) begin
       if (dcr_bus_if.write_vld) begin
            case (dcr_bus_if.write_addr)
            VX_DCR_BASE_STARTUP_ADDR0 : dcrs_startup_addr[31:0] <= dcr_bus_if.write_data;
        `ifdef XLEN_64
            VX_DCR_BASE_STARTUP_ADDR1 : dcrs_startup_addr[63:32] <= dcr_bus_if.write_data;
        `endif
            VX_DCR_BASE_STARTUP_ARG0 : dcrs_startup_arg[31:0] <= dcr_bus_if.write_data;
        `ifdef XLEN_64
            VX_DCR_BASE_STARTUP_ARG1 : dcrs_startup_arg[63:32] <= dcr_bus_if.write_data;
        `endif
            VX_DCR_BASE_MPM_CLASS : dcrs_mpm_class <= dcr_bus_if.write_data[7:0];
            default:;
            endcase
        end
    end

    assign base_dcrs.startup_addr = dcrs_startup_addr;
    assign base_dcrs.startup_arg = dcrs_startup_arg;
    assign base_dcrs.mpm_class = dcrs_mpm_class;

`ifdef DBG_TRACE_PIPELINE
    always @(posedge clk_i) begin
        if (dcr_bus_if.write_vld) begin
            `TRACE(2, ("%t: base-dcr: state=", $time))
            trace_base_dcr(1, dcr_bus_if.write_addr);
            `TRACE(2, (", data=0x%h\n", dcr_bus_if.write_data))
        end
    end
`endif

endmodule
