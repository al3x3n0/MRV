// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICEN_PSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRAN_PTIES OR CON_PDITION_PS OF AN_PY KIN_PD, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


module xrv_transpose #(
    parameter DATA_WIDTH_P = 1,
    parameter N_P = 1,
    parameter M_P = 1
) (
    input  logic [N_P-1:0][M_P-1:0][DATA_WIDTH_P-1:0] data_i,
    output logic [M_P-1:0][N_P-1:0][DATA_WIDTH_P-1:0] data_o
);
    for (genvar i = 0; i < N_P; ++i) begin : g_i
        for (genvar j = 0; j < M_P; ++j) begin : g_j
            assign data_o[j][i] = data_i[i][j];
        end
    end

endmodule
