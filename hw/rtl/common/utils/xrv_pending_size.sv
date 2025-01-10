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


module xrv_pending_size #(
    ////////////////////////////////////////////////////////////////////////////////
    parameter SIZE_P            = 1,
    parameter INCR_WIDTH_P      = 1,
    parameter DECR_WIDTH_P      = 1,
    parameter ALM_FULL_P          = (SIZE_P - 1),
    parameter ALM_EMPTY_P         = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter SIZE_WIDTH_LP     = `XM_CLOG2(SIZE_P+1)
) (
    ////////////////////////////////////////////////////////////////////////////////
    input  logic  clk_i,
    input  logic  rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [INCR_WIDTH_P-1:0] incr,
    input  logic [DECR_WIDTH_P-1:0] decr,
    output logic empty,
    output logic alm_empty,
    output logic full,
    output logic alm_full,
    output logic [SIZE_WIDTH_LP-1:0] size
);
    `STATIC_ASSERT(INCR_WIDTH_P <= SIZE_WIDTH_LP, ("invalid parameter: %d vs %d", INCR_WIDTH_P, SIZE_WIDTH_LP))
    `STATIC_ASSERT(DECR_WIDTH_P <= SIZE_WIDTH_LP, ("invalid parameter: %d vs %d", DECR_WIDTH_P, SIZE_WIDTH_LP))

    if (SIZE_P == 1) begin : g_size_eq1

        reg size_r;

        always_ff @(posedge clk_i) begin
            if (rst_i) begin
                size_r <= '0;
            end else begin
                if (incr) begin
                    if (~decr) begin
                        size_r <= 1;
                    end
                end else if (decr) begin
                    size_r <= '0;
                end
            end
        end

        assign empty     = (size_r == 0);
        assign full      = (size_r != 0);
        assign alm_empty = 1'b1;
        assign alm_full  = 1'b1;
        assign size      = size_r;

    end else begin : g_size_gt1

        reg empty_r, alm_empty_r;
        reg full_r, alm_full_r;

        if (INCR_WIDTH_P != 1 || DECR_WIDTH_P != 1) begin : g_wide_step

            localparam DELTA_WIDTH_LP = `XM_MIN(SIZE_WIDTH_LP, `XM_MAX(INCR_WIDTH_P, DECR_WIDTH_P)+1);

            logic [SIZE_WIDTH_LP-1:0] size_n, size_r;

            wire [DELTA_WIDTH_LP-1:0] delta = DELTA_WIDTH_LP'(incr) - DELTA_WIDTH_LP'(decr);

            assign size_n = $signed(size_r) + SIZE_WIDTH_LP'($signed(delta));

            always_ff @(posedge clk_i) begin
                if (rst_i) begin
                    empty_r     <= 1;
                    full_r      <= 0;
                    alm_empty_r <= 1;
                    alm_full_r  <= 0;
                    size_r      <= '0;
                end else begin
                    `ASSERT((DELTA_WIDTH_LP'(incr) <= DELTA_WIDTH_LP'(decr)) || (size_n >= size_r), ("runtime error: counter overflow"));
                    `ASSERT((DELTA_WIDTH_LP'(incr) >= DELTA_WIDTH_LP'(decr)) || (size_n <= size_r), ("runtime error: counter underflow"));
                    empty_r     <= (size_n == SIZE_WIDTH_LP'(0));
                    full_r      <= (size_n == SIZE_WIDTH_LP'(SIZE_P));
                    alm_empty_r <= (size_n <= SIZE_WIDTH_LP'(ALM_EMPTY_P));
                    alm_full_r  <= (size_n >= SIZE_WIDTH_LP'(ALM_FULL_P));
                    size_r      <= size_n;
                end
            end

            assign size = size_r;

        end else begin : g_single_step

            localparam ADDR_WIDTH_LP = `XM_LOG2UP(SIZE_P);

            reg [ADDR_WIDTH_LP-1:0] used_r;

            wire is_alm_empty   = (used_r == ADDR_WIDTH_LP'(ALM_EMPTY_P));
            wire is_alm_empty_n = (used_r == ADDR_WIDTH_LP'(ALM_EMPTY_P+1));
            wire is_alm_full    = (used_r == ADDR_WIDTH_LP'(ALM_FULL_P));
            wire is_alm_full_n  = (used_r == ADDR_WIDTH_LP'(ALM_FULL_P-1));

            always_ff @(posedge clk_i) begin
                if (rst_i) begin
                    alm_empty_r <= 1;
                    alm_full_r  <= 0;
                end else begin
                    if (incr) begin
                        if (~decr) begin
                            if (is_alm_empty)
                                alm_empty_r <= 0;
                            if (is_alm_full_n)
                                alm_full_r <= 1;
                        end
                    end else if (decr) begin
                        if (is_alm_full)
                            alm_full_r <= 0;
                        if (is_alm_empty_n)
                            alm_empty_r <= 1;
                    end
                end
            end

            if (SIZE_P > 2) begin : g_size_gt2

                wire is_empty_n = (used_r == ADDR_WIDTH_LP'(1));
                wire is_full_n  = (used_r == ADDR_WIDTH_LP'(SIZE_P-1));

                wire [1:0] delta = {~incr & decr, incr ^ decr};

                always_ff @(posedge clk_i) begin
                    if (rst_i) begin
                        empty_r <= 1;
                        full_r  <= 0;
                        used_r  <= '0;
                    end else begin
                        if (incr) begin
                            if (~decr) begin
                                empty_r <= 0;
                                if (is_full_n)
                                    full_r <= 1;
                            end
                        end else if (decr) begin
                            full_r <= 0;
                            if (is_empty_n)
                                empty_r <= 1;
                        end
                        used_r <= $signed(used_r) + ADDR_WIDTH_LP'($signed(delta));
                    end
                end

            end else begin : g_size_eq2

                always_ff @(posedge clk_i) begin
                    if (rst_i) begin
                        empty_r <= 1;
                        full_r  <= 0;
                        used_r  <= '0;
                    end else begin
                        empty_r <= (empty_r & ~incr) | (~full_r & decr & ~incr);
                        full_r  <= (~empty_r & incr & ~decr) | (full_r & ~(decr ^ incr));
                        used_r  <= used_r ^ (incr ^ decr);
                    end
                end
            end

            if (SIZE_P > 1) begin : g_sizeN
                if (SIZE_WIDTH_LP > ADDR_WIDTH_LP) begin : g_not_log2
                    assign size = {full_r, used_r};
                end else begin : g_log2
                    assign size = used_r;
                end
            end else begin : g_size1
                assign size = full_r;
            end

        end

        assign empty     = empty_r;
        assign full      = full_r;
        assign alm_empty = alm_empty_r;
        assign alm_full  = alm_full_r;

    end

endmodule
