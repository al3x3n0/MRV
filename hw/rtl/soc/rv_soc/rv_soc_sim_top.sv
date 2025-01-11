`include "rtl/common/defines.sv"
`include "xm_cores.svh"
`include "xm_macro.svh"
`include "pkg/xrv1_pkg.sv"
`include "pkg/mrv1_pkg.sv"

// c++ function to decode risc-v instruction
import "DPI-C" function string riscv_decode_instruction(input int pc, input int inst);

module rv_soc_sim_top #(
    parameter DEBUG_LEVEL_P = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter CPU_NUM_CORES_P = 1,
    parameter NUM_THREADS_P   = 8,
    parameter XLEN_P = 32,
    parameter CPU_RESET_ADDRESS_P = 'h2000,
    parameter RAM_BITS_SIZE_P = 16,
    parameter PC_WIDTH_P = XLEN_P,
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_LP = `XM_CLOG2(NUM_THREADS_P),
    parameter IMEM_TAG_WIDTH_P = PC_WIDTH_P + TID_WIDTH_LP,
    parameter DMEM_TAG_WIDTH_P = 3 + TID_WIDTH_LP
) (
    ////////////////////////////////////////////////////////////////////////////////
    input logic                                 clk_i,
    input logic                                 rst_i
    ////////////////////////////////////////////////////////////////////////////////
);
    ////////////////////////////////////////////////////////////////////////////////
    // Instruction memory interface
    ////////////////////////////////////////////////////////////////////////////////
    logic                       imem_req_vld;
    logic                       imem_req_rdy;
    logic [31:0]                imem_req_addr;
    logic                       imem_resp_vld;
    logic [31:0]                imem_resp_data;
    ////////////////////////////////////////////////////////////////////////////////
    // Data memory interface
    ////////////////////////////////////////////////////////////////////////////////
    logic                       dmem_req_vld;
    logic                       dmem_req_rdy;
    logic                       dmem_resp_err;
    logic [31:0]                dmem_req_addr;
    logic                       dmem_req_w_en;
    logic [3:0]                 dmem_req_w_be;
    logic [31:0]                dmem_req_w_data;
    logic                       dmem_resp_vld;
    logic [31:0]                dmem_resp_r_data;
    ////////////////////////////////////////////////////////////////////////////////

    generate
        if (DEBUG_LEVEL_P > 0) initial begin
            $display("Current parameters: \
                      DEBUG_LEVEL_P       %8d \
                      CPU_NUM_CORES_P     %8d \
                      NUM_THREADS_P       %8d \
                      XLEN_P              %8d \
                      CPU_RESET_ADDRESS_P %8h \
                      RAM_BITS_SIZE_P     %8d \
                      PC_WIDTH_P          %8d \
                      TID_WIDTH_LP        %8d \
                      IMEM_TAG_WIDTH_P    %8d \
                      DMEM_TAG_WIDTH_P    %8d\n", DEBUG_LEVEL_P, CPU_NUM_CORES_P,
                      NUM_THREADS_P, XLEN_P, CPU_RESET_ADDRESS_P, RAM_BITS_SIZE_P,
                      PC_WIDTH_P, TID_WIDTH_LP, IMEM_TAG_WIDTH_P, DMEM_TAG_WIDTH_P);
        end
    endgenerate

`ifdef TB_CORE_TYPE_XRV1
    ////////////////////////////////////////////////////////////////////////////////
    // XRV1 core instance
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_core #(
        .CORE_RESET_ADDR(CPU_RESET_ADDRESS_P)
    ) core_i [CPU_NUM_CORES_P-1:0] (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .imem_req_vld_o             (imem_req_vld),
        .imem_req_rdy_i             (imem_req_rdy),
        .imem_req_addr_o            (imem_req_addr),
        .imem_resp_vld_i            (imem_resp_vld),
        .imem_resp_data_i           (imem_resp_data),
        ////////////////////////////////////////////////////////////////////////////////
        .dmem_req_vld_o             (dmem_req_vld),
        .dmem_req_rdy_i             (dmem_req_rdy),
        .dmem_resp_err_i            (/*FIXME*/),
        .dmem_req_addr_o            (dmem_req_addr),
        .dmem_req_w_en_o            (dmem_req_w_en),
        .dmem_req_w_be_o            (dmem_req_w_be),
        .dmem_req_w_data_o          (dmem_req_w_data),
        .dmem_resp_vld_i            (dmem_resp_vld),
        .dmem_resp_r_data_i         (dmem_resp_r_data)
        ////////////////////////////////////////////////////////////////////////////////
    );
`elsif TB_CORE_TYPE_MRV1
    ////////////////////////////////////////////////////////////////////////////////
    // MRV1 core instance
    ////////////////////////////////////////////////////////////////////////////////
    logic [DMEM_TAG_WIDTH_P-1:0] dmem_tag_q, dmem_req_tag_lo, dmem_resp_tag_li;
    logic [IMEM_TAG_WIDTH_P-1:0] imem_tag_q, imem_req_tag_lo, imem_resp_tag_li;
    always_ff @(posedge clk_i) begin
        dmem_tag_q <= dmem_req_tag_lo;
        imem_tag_q <= imem_req_tag_lo;
    end
    assign imem_resp_tag_li = imem_tag_q;
    assign dmem_resp_tag_li = dmem_tag_q;

    mrv1_core #(
        .CORE_RESET_ADDR    (CPU_RESET_ADDRESS_P),
        .NUM_THREADS_P      (NUM_THREADS_P)
    ) core_i [CPU_NUM_CORES_P-1:0] (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        .rst_i                      (rst_i),
        ////////////////////////////////////////////////////////////////////////////////
        .fetch_en_i                 (1'b1),
        .simt_en_i                  (1'b0),
        ////////////////////////////////////////////////////////////////////////////////
        .imem_req_vld_o             (imem_req_vld),
        .imem_req_rdy_i             (imem_req_rdy),
        .imem_req_addr_o            (imem_req_addr),
        .imem_req_tag_o             (imem_req_tag_lo),
        .imem_resp_vld_i            (imem_resp_vld),
        .imem_resp_data_i           (imem_resp_data),
        .imem_resp_tag_i            (imem_resp_tag_li),
        ////////////////////////////////////////////////////////////////////////////////
        .dmem_req_vld_o             (dmem_req_vld),
        .dmem_req_rdy_i             (dmem_req_rdy),
        .dmem_resp_err_i            (/*FIXME*/),
        .dmem_req_addr_o            (dmem_req_addr),
        .dmem_req_w_en_o            (dmem_req_w_en),
        .dmem_req_w_be_o            (dmem_req_w_be),
        .dmem_req_tag_o             (dmem_req_tag_lo),
        .dmem_req_w_data_o          (dmem_req_w_data),
        .dmem_resp_vld_i            (dmem_resp_vld),
        .dmem_resp_tag_i            (dmem_resp_tag_li),
        .dmem_resp_r_data_i         (dmem_resp_r_data)
        ////////////////////////////////////////////////////////////////////////////////
    );
`endif

    // TODO: support more complicated RAM model with caches and AXI bus under ifdef
    // along with existing 

    ////////////////////////////////////////////////////////////////////////////////
    // TCM simulation model
    ////////////////////////////////////////////////////////////////////////////////
    xrv1_sim_tcm #(
        .itcm_size_p(1 << RAM_BITS_SIZE_P),
        .dtcm_size_p(1 << RAM_BITS_SIZE_P)
    ) tcm_i (
        ////////////////////////////////////////////////////////////////////////////////
        .clk_i                      (clk_i),
        ////////////////////////////////////////////////////////////////////////////////
        .imem_req_vld_i             (imem_req_vld),
        .imem_req_rdy_o             (imem_req_rdy),
        .imem_req_addr_i            (imem_req_addr),
        .imem_resp_vld_o            (imem_resp_vld),
        .imem_resp_data_o           (imem_resp_data),
        ////////////////////////////////////////////////////////////////////////////////
        .dmem_req_vld_i             (dmem_req_vld),
        .dmem_req_rdy_o             (dmem_req_rdy),
        .dmem_resp_err_o            (/*FIXME*/),
        .dmem_req_addr_i            (dmem_req_addr),
        .dmem_req_w_en_i            (dmem_req_w_en),
        .dmem_req_w_be_i            (dmem_req_w_be),
        .dmem_req_w_data_i          (dmem_req_w_data),
        .dmem_resp_vld_o            (dmem_resp_vld),
        .dmem_resp_r_data_o         (dmem_resp_r_data)
        ////////////////////////////////////////////////////////////////////////////////
    );
    ////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// Verification routines
////////////////////////////////////////////////////////////////////////////////
export "DPI-C" task get_ram_size_bits;
task get_ram_size_bits
(
    output int bits
);
    bits = rv_soc_sim_top.tcm_i.itcm_size_p;
endtask

export "DPI-C" task write_u8;
task write_u8
(
    input int addr,
    input byte data
);
    rv_soc_sim_top.tcm_i.itcm_i.write_u8(addr, data);
endtask

export "DPI-C" task read_u8;
task read_u8
(
    input int addr,
    output byte data
);
    data = rv_soc_sim_top.tcm_i.itcm_i.read_u8(addr);
endtask


`ifdef TB_CORE_TYPE_XRV1
    `include "ucore/ucore_dpi.svh"
`elsif TB_CORE_TYPE_MRV1
    `include "mtcore/mtcore_dpi.svh"
`endif

export "DPI-C" task soc_read_arch_register;
task soc_read_arch_register
(
    input int core_id,
    input int hart_id,
    input int reg_addr,
    output longint val
);
    case (core_id)
        0: val = core_i[0].read_arch_register(hart_id, reg_addr);
    endcase
endtask

export "DPI-C" task soc_write_arch_register;
task soc_write_arch_register
(
    input int core_id,
    input int hart_id,
    input int reg_addr,
    input longint val
);
    case (core_id)
        0: core_i[0].write_arch_register(hart_id, reg_addr, val);
    endcase
endtask

endmodule
