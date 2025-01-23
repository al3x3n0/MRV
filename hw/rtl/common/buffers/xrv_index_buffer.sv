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


`TRACING_OFF
module xrv_index_buffer #(
    parameter DATA_WIDTH_P  = 1,
    parameter SIZE_P        = 1,
    parameter LUTRAM        = 0,
    parameter ADDR_WIDTH_P  = `XM_LOG2UP(SIZE_P)
) (
    input  wire             clk_i,
    input  wire             rst_i,

    output wire [ADDR_WIDTH_P-1:0] write_addr,
    input  wire [DATA_WIDTH_P-1:0] write_data,
    input  wire             acquire_en,

    input  wire [ADDR_WIDTH_P-1:0] read_addr,
    output wire [DATA_WIDTH_P-1:0] read_data,
    input  wire             release_en,

    output wire             empty,
    output wire             full
);

    xrv_allocator #(
        .SIZE_P (SIZE_P)
    ) allocator (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .acquire_en_i   (acquire_en),
        .acquire_addr   (write_addr),
        .release_en_i   (release_en),
        .release_addr_i (read_addr),
        .empty_o        (empty),
        .full_o         (full)
    );

    xrv_mem_r1w1 #(
        .DATA_WIDTH_P   (DATA_WIDTH_P),
        .DEPTH_P        (SIZE_P)
        //.LUTRAM         (LUTRAM),
        //.RDW_MODE       ("W") FIXME
    ) data_table (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .do_wr_i        (acquire_en),
        .wr_addr_i      (write_addr),
        .wr_data_i      (write_data),
        .rd_addr_i      (read_addr),
        .rd_data_o      (read_data)
    );

endmodule
`TRACING_ON
