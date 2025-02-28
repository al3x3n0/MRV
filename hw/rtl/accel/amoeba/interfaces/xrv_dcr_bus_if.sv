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

interface xrv_vx_dcr_bus_if import amoeba_gpu_pkg::*; ();

    wire                          write_vld;
    wire [VX_DCR_ADDR_WIDTH-1:0] write_addr;
    wire [VX_DCR_DATA_WIDTH-1:0] write_data;

    modport master (
        output write_vld,
        output write_addr,
        output write_data
    );

    modport slave (
        input  write_vld,
        input  write_addr,
        input  write_data
    );

endinterface
