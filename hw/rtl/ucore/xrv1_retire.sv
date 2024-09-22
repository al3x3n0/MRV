module xrv1_retire
#(
    parameter DATA_WIDTH_P = 32,
    parameter rf_addr_width_p = 5,
    parameter ITAG_WIDTH_P = "inv",
    parameter iqueue_size_lp = (1 << ITAG_WIDTH_P),
    parameter num_fu_lp = 6,
    parameter num_rs_lp = 2
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                         clk_i,
    input logic                                         rst_i,
    ////////////////////////////////////////////////////////////////////////////////
    // ALU -> WBACK interface
    ////////////////////////////////////////////////////////////////////////////////
    input logic [num_fu_lp-1:0]                                 fu_done_i,
    input logic [num_fu_lp-1:0][31:0]                           fu_wb_data_i,
    input logic [num_fu_lp-1:0][ITAG_WIDTH_P-1:0]               fu_itag_i,
    ////////////////////////////////////////////////////////////////////////////////
    // IQueue -> WBACK interface
    ////////////////////////////////////////////////////////////////////////////////
    input logic [ITAG_WIDTH_P-1:0]                              issue_itag_i,
    input logic [ITAG_WIDTH_P-1:0]                              retire_itag_i,
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                                 retire_rdy_i,
    output logic [ITAG_WIDTH_P-1:0]                             retire_cnt_o,
    input logic [rf_addr_width_p-1:0]                           retire_rd_addr_i,
    ////////////////////////////////////////////////////////////////////////////////
    output logic [rf_addr_width_p-1:0]                          wb_rd_addr_o,
    output logic                                                wb_data_vld_o,
    output logic [DATA_WIDTH_P-1:0]                             wb_data_o,
    ////////////////////////////////////////////////////////////////////////////////
    input  logic [num_rs_lp-1:0][iqueue_size_lp-1:0]            rs_conflict_i,
    output logic [num_rs_lp-1:0]                                rs_conflict_o,
    output logic [num_rs_lp-1:0]                                rs_byp_en_o,
    output logic [num_rs_lp-1:0][31:0]                          rs_byp_data_o,
    ////////////////////////////////////////////////////////////////////////////////
    input logic [iqueue_size_lp-1:0]                            iqueue_vld_i,
    input logic [iqueue_size_lp-1:0]                            iqueue_rd_vld_i,
    input logic [iqueue_size_lp-1:0][rf_addr_width_p-1:0]       iqueue_rd_addr_i
    ////////////////////////////////////////////////////////////////////////////////
);
    always_comb begin
        $display("fu_done=%b alu_itag=%d",
            fu_done_i, fu_itag_i[0]);
    end
    ////////////////////////////////////////////////////////////////////////////////
    // Write-back buffer
    ////////////////////////////////////////////////////////////////////////////////
    logic [iqueue_size_lp-1:0]          wb_mem_vld_q, wb_mem_vld_n;
    logic [iqueue_size_lp-1:0][31:0]    wb_mem_data_q, wb_mem_data_n;
    ////////////////////////////////////////////////////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (rst_i)
            wb_mem_vld_q <= '0;
        else begin
            wb_mem_vld_q  <= wb_mem_vld_n;
            wb_mem_data_q <= wb_mem_data_n;
        end
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Retire count
    ////////////////////////////////////////////////////////////////////////////////
    logic [iqueue_size_lp-1:0][ITAG_WIDTH_P-1:0] tmp0_ptr;
    logic [ITAG_WIDTH_P-1:0] ret_cnt_r;
    always_comb begin
        wb_mem_vld_n = wb_mem_vld_q;
        wb_mem_data_n = wb_mem_data_q;
        wb_data_vld_o = 1'b0;
        ret_cnt_r = 0;
        // TODO: review this part
        // Added missing initializations
        wb_rd_addr_o = 'b0;
        wb_data_o = 'b0;
        // 
        ////////////////////////////////////////////////////////////////////////////////
        for (int i = 0; i < num_fu_lp; i = i + 1) begin
            if (fu_done_i[i]) begin
                wb_mem_vld_n[fu_itag_i[i]]  = 1'b1;
                wb_mem_data_n[fu_itag_i[i]] = fu_wb_data_i[i];
                $display("done: itag=%d", fu_itag_i[i]);
            end
        end
        $display("wb_mem_vld_n=%b ret_itag=%d", wb_mem_vld_n, retire_itag_i);
        ////////////////////////////////////////////////////////////////////////////////
        for (int i = 0; i < iqueue_size_lp; i = i + 1) begin
            assign tmp0_ptr[i] = retire_itag_i + i[ITAG_WIDTH_P-1:0];
            if (~wb_mem_vld_n[tmp0_ptr[i]])
                break;
            $display("CHECKING: itag=%d", tmp0_ptr[i]);
            if (iqueue_rd_vld_i[tmp0_ptr[i]]) begin
                if (~wb_data_vld_o) begin
                    wb_data_vld_o = 1'b1;
                    wb_rd_addr_o = iqueue_rd_addr_i[tmp0_ptr[i]];
                    wb_data_o = wb_mem_data_n[tmp0_ptr[i]];
                end
                else
                    break;
            end
            $display("CHECKING2: itag=%d", tmp0_ptr[i]);
            ret_cnt_r = ret_cnt_r + 1'b1;
            wb_mem_vld_n[tmp0_ptr[i]] = 1'b0;
            $display("RET: itag=%d", tmp0_ptr[i]);
        end
        ////////////////////////////////////////////////////////////////////////////////

    end
    ////////////////////////////////////////////////////////////////////////////////
    assign retire_cnt_o = ret_cnt_r;
    always_comb begin
        $display("retire_cnt_o=%d", retire_cnt_o);
    end
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////
    // Bypasses
    ////////////////////////////////////////////////////////////////////////////////
    genvar j;
    generate
        for (j = 0; j < num_rs_lp; j = j + 1) begin
            logic [iqueue_size_lp-1:0][ITAG_WIDTH_P-1:0] tmp_ptr;
            // TODO: review this part
            // Replaced always_comb with always_latch as crutch to satisfy verilator
            always_latch begin
            // 
                rs_conflict_o[j] = (|rs_conflict_i[j]);
                rs_byp_en_o[j] = 1'b0;
                for (int i = 1; i < iqueue_size_lp; i = i + 1) begin
                    assign tmp_ptr[i] = issue_itag_i - i[ITAG_WIDTH_P-1:0];
                    for (int k = 0; k < num_fu_lp; k++) begin
                        if (rs_conflict_i[j][tmp_ptr[i]] & fu_itag_i[k] == tmp_ptr[i] & fu_done_i[k]) begin
                            rs_byp_en_o[j]   = 1'b1;
                            rs_byp_data_o[j] = fu_wb_data_i[k];
                            break;
                        end
                    end
                    if (~rs_byp_en_o[j] & rs_conflict_i[j][tmp_ptr[i]] & wb_mem_vld_q[tmp_ptr[i]]) begin
                        rs_byp_en_o[j]   = 1'b1;
                        rs_byp_data_o[j] = wb_mem_data_q[tmp_ptr[i]];
                    end
                    if (rs_byp_en_o[j]) begin
                        $display("BYPASS: rs %d %h", j, rs_byp_data_o[j]);
                        rs_conflict_o[j] = 1'b0;
                        break;
                    end
                end
            end
        end
    endgenerate
    ////////////////////////////////////////////////////////////////////////////////
endmodule
