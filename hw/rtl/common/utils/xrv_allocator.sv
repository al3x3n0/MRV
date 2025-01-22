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
module xrv_allocator #(
    parameter SIZE_P        = 1,
    parameter ADDR_WIDTH_P  = `XM_LOG2UP(SIZE_P)
) (
    input  wire                     clk_i,
    input  wire                     rst_i,

    input  wire                     acquire_en_i,    
    output wire [ADDR_WIDTH_P-1:0]  acquire_addr,      
    
    input  wire                     release_en_i,
    input  wire [ADDR_WIDTH_P-1:0]  release_addr_i,    
    
    output wire                     empty_o,
    output wire                     full_o
);
    logic [SIZE_P-1:0] free_slots, free_slots_n;
    logic [ADDR_WIDTH_P-1:0] acquire_addr_r;
    logic empty_r, full_r;    
    wire [ADDR_WIDTH_P-1:0] free_index;
    wire free_valid;

    always_comb begin
        free_slots_n = free_slots;
        if (release_en_i) begin
            free_slots_n[release_addr_i] = 1;                
        end
        if (acquire_en_i) begin
            free_slots_n[acquire_addr_r] = 0;
        end            
    end

    xrv_lzc #(
        .N          (SIZE_P),
        .REVERSE_P  (1)
    ) free_slots_sel (
        .data_i     (free_slots_n),
        .data_o     (free_index),
        .vld_o      (free_valid)
    );  

    always @(posedge clk_i) begin
        if (rst_i) begin
            acquire_addr_r <= ADDR_WIDTH_P'(1'b0);
            free_slots     <= {SIZE_P{1'b1}};
            empty_r        <= 1'b1;
            full_r         <= 1'b0;            
        end else begin
            if (release_en_i) begin
                `ASSERT(0 == free_slots[release_addr_i], ("%t: releasing invalid addr %d", $time, release_addr_i));
            end
            if (acquire_en_i) begin                
                `ASSERT(~full_r, ("%t: allocator is full", $time));
            end            
            
            if (acquire_en_i || (release_en_i && full_r)) begin
                acquire_addr_r <= free_index;
            end

            free_slots <= free_slots_n;           
            empty_r    <= (& free_slots_n);
            full_r     <= ~free_valid;
        end        
    end
        
    assign acquire_addr     = acquire_addr_r;
    assign empty_o          = empty_r;
    assign full_o           = full_r;
    
endmodule
`TRACING_ON
