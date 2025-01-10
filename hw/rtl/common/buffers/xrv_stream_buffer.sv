// Copyright 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// A stream elastic buffer_q operates at full-bandwidth where fire_in and fire_out can happen simultaneously
// It has the following benefits:
// + full-bandwidth throughput
// + rdy_i and rdy_o are decoupled
// + data_o can be fully registered
// It has the following limitations:
// - requires two registers for storage
////////////////////////////////////////////////////////////////////////////////


module xrv_stream_buffer #(
	////////////////////////////////////////////////////////////////////////////////
    parameter DATA_WIDTH_P    	= 1,
	parameter OUT_REG  			= 0,
    parameter PASSTHRU 			= 0
) (
	////////////////////////////////////////////////////////////////////////////////
    input  logic             			clk_i,
    input  logic             			rst_i,
	////////////////////////////////////////////////////////////////////////////////
    input  logic             			vld_i,
    output logic             			rdy_i,
    input  logic [DATA_WIDTH_P-1:0] 	data_i,
    output logic [DATA_WIDTH_P-1:0] 	data_o,
    input  logic             			rdy_o,
    output logic             			vld_o
);
    if (PASSTHRU != 0) begin : g_passthru

        `XM_UNUSED_VAR (clk_i)
        `XM_UNUSED_VAR (rst_i)
        assign rdy_i  = rdy_o;
        assign vld_o = vld_i;
        assign data_o  = data_i;

	end else begin : g_buffer

		reg [DATA_WIDTH_P-1:0] data_o_q, buffer_q;
		reg vld_o_q, vld_i_q;

		wire fire_in = vld_i && rdy_i;
		wire flow_out = rdy_o || ~vld_o;

		always_ff @(posedge clk_i) begin
			if (rst_i) begin
				vld_i_q <= 1'b1;
			end else if (vld_i || flow_out) begin
				vld_i_q <= flow_out;
			end
		end

		always_ff @(posedge clk_i) begin
			if (rst_i) begin
				vld_o_q <= 1'b0;
			end else if (flow_out) begin
				vld_o_q <= vld_i || ~vld_i_q;
			end
		end

		if (OUT_REG != 0) begin : g_out_qeg

			always_ff @(posedge clk_i) begin
				if (fire_in) begin
					buffer_q <= data_i;
				end
			end

			always_ff @(posedge clk_i) begin
				if (flow_out) begin
					data_o_q <= vld_i_q ? data_i : buffer_q;
				end
			end

			assign data_o = data_o_q;

		end else begin : g_no_out_qeg

			always_ff @(posedge clk_i) begin
				if (fire_in) begin
					data_o_q <= data_i;
				end
			end

			always_ff @(posedge clk_i) begin
				if (fire_in) begin
					buffer_q <= data_o_q;
				end
			end

			assign data_o  = vld_i_q ? data_o_q : buffer_q;

		end

		assign vld_o = vld_o_q;
		assign rdy_i  = vld_i_q;

	end

endmodule
