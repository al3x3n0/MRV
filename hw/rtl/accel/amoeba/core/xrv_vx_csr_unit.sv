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

module xrv_vx_csr_unit import amoeba_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = "",
    parameter CORE_ID = 0,
    ////////////////////////////////////////////////////////////////////////////////
    parameter XLEN_P            = 64,
    parameter PC_WIDTH_P        = XLEN_P - 1,
    parameter NUM_LANES_P       = 1,
    ////////////////////////////////////////////////////////////////////////////////
    parameter NUM_WARPS_P       = "inv",
    parameter NUM_THREADS_P     = "inv",
    parameter WID_WIDTH_P       = `XM_CLOG2(NUM_WARPS_P),
    parameter TID_WIDTH_P       = `XM_CLOG2(NUM_THREADS_P),
    ////////////////////////////////////////////////////////////////////////////////
    parameter UUID_WIDTH_P      = "inv",
    parameter NUM_FPU_BLOCKS_P  = "inv"

) (
    input wire                      clk_i,
    input wire                      rst_i,

    input xrv_vx_base_dcrs_if       base_dcrs,

`ifdef PERF_ENABLE
    xrv_vx_mem_perf_if.slave        mem_perf_if,
    xrv_vx_pipeline_perf_if.slave   pipeline_perf_if,
`endif

`ifdef EXT_F_ENABLE
    xrv_vx_fpu_csr_if.slave         fpu_csr_if [NUM_FPU_BLOCKS_P],
`endif

    xrv_vx_commit_csr_if.slave      commit_csr_if,
    xrv_vx_sched_csr_if.slave       sched_csr_if,
    xrv_vx_execute_if.slave         execute_if,
    xrv_vx_commit_if.master         commit_if
);
    `XM_UNUSED_SPARAM (INSTANCE_ID)
    localparam DATA_WIDTH_P = UUID_WIDTH_P + WID_WIDTH_P + NUM_LANES_P + PC_WIDTH_P + VX_NR_BITS + 1 + NUM_LANES_P * XLEN_P;

    `XM_UNUSED_VAR (execute_if.data.rs3_data)

    reg [NUM_LANES_P-1:0][XLEN_P-1:0]  csr_read_data;
    reg  [XLEN_P-1:0]                csr_write_data;
    wire [XLEN_P-1:0]                csr_read_data_ro, csr_read_data_rw;
    wire [XLEN_P-1:0]                csr_req_data;
    reg                             csr_rd_enable;
    wire                            csr_wr_enable;
    wire                            csr_req_rdy;

    wire [VX_CSR_ADDR_BITS-1:0] csr_addr = execute_if.data.op_args.csr.addr;
    wire [VX_NRI_BITS-1:0] csr_imm = execute_if.data.op_args.csr.imm;

    wire is_fpu_csr = (csr_addr <= VX_CSR_FCSR);

    // wait for all pending instructions for current warp to complete
    assign sched_csr_if.alm_empty_wid = execute_if.data.wid;
    wire no_pending_instr = sched_csr_if.alm_empty || ~is_fpu_csr;

    wire csr_req_vld = execute_if.vld && no_pending_instr;
    assign execute_if.rdy = csr_req_rdy && no_pending_instr;

    wire [NUM_LANES_P-1:0][XLEN_P-1:0] rs1_data;
    `XM_UNUSED_VAR (rs1_data)
    for (genvar i = 0; i < NUM_LANES_P; ++i) begin : g_rs1_data
        assign rs1_data[i] = execute_if.data.rs1_data[i];
    end

    wire csr_write_enable = (execute_if.data.op_type == VX_INST_SFU_CSRRW);

    xrv_vx_csr_data #(
        .INSTANCE_ID    (INSTANCE_ID),
        .CORE_ID        (CORE_ID),
        ////////////////////////////////////////////////////////////////////////////////
        .XLEN_P         (XLEN_P),
        .NUM_THREADS_P  (NUM_THREADS_P),
        .NUM_WARPS_P    (NUM_WARPS_P),
        .UUID_WIDTH_P   (UUID_WIDTH_P)
    ) csr_data (
        .clk_i          (clk_i),
        .rst_i          (rst_i),

        .base_dcrs      (base_dcrs),

    `ifdef PERF_ENABLE
        .mem_perf_if    (mem_perf_if),
        .pipeline_perf_if(pipeline_perf_if),
    `endif

        .commit_csr_if  (commit_csr_if),
        .cycles         (sched_csr_if.cycles),
        .active_warps   (sched_csr_if.active_warps),
        .thread_masks   (sched_csr_if.thread_masks),

    `ifdef EXT_F_ENABLE
        .fpu_csr_if     (fpu_csr_if),
    `endif

        .read_enable    (csr_req_vld && csr_rd_enable),
        .read_uuid      (execute_if.data.uuid),
        .read_wid       (execute_if.data.wid),
        .read_addr      (csr_addr),
        .read_data_ro   (csr_read_data_ro),
        .read_data_rw   (csr_read_data_rw),

        .write_enable   (csr_req_vld && csr_wr_enable),
        .write_uuid     (execute_if.data.uuid),
        .write_wid      (execute_if.data.wid),
        .write_addr     (csr_addr),
        .write_data     (csr_write_data)
    );

    // CSR read

    wire [NUM_LANES_P-1:0][XLEN_P-1:0] wtid, gtid;

    for (genvar i = 0; i < NUM_LANES_P; ++i) begin : g_wtid
        assign wtid[i] = XLEN_P'(i);
    end

    for (genvar i = 0; i < NUM_LANES_P; ++i) begin : g_gtid
        assign gtid[i] = (XLEN_P'(CORE_ID) << (WID_WIDTH_P + TID_WIDTH_P)) + (XLEN_P'(execute_if.data.wid) << TID_WIDTH_P) + wtid[i];
    end

    always @(*) begin
        csr_rd_enable = 0;
        case (csr_addr)
        VX_CSR_THREAD_ID : csr_read_data = wtid;
        VX_CSR_MHARTID   : csr_read_data = gtid;
        default : begin
            csr_read_data = {NUM_LANES_P{csr_read_data_ro | csr_read_data_rw}};
            csr_rd_enable = 1;
        end
        endcase
    end

    // CSR write

    assign csr_req_data = execute_if.data.op_args.csr.use_imm ? XLEN_P'(csr_imm) : rs1_data[0];
    assign csr_wr_enable = (csr_write_enable || (| csr_req_data));

    always @(*) begin
        case (execute_if.data.op_type)
            VX_INST_SFU_CSRRW: begin
                csr_write_data = csr_req_data;
            end
            VX_INST_SFU_CSRRS: begin
                csr_write_data = csr_read_data_rw | csr_req_data;
            end
            //VX_INST_SFU_CSRRC
            default: begin
                csr_write_data = csr_read_data_rw & ~csr_req_data;
            end
        endcase
    end

    // unlock the warp
    assign sched_csr_if.unlock_warp = csr_req_vld && csr_req_rdy && is_fpu_csr;
    assign sched_csr_if.unlock_wid = execute_if.data.wid;

    xrv_elastic_buffer #(
        .DATA_WIDTH_P   (DATA_WIDTH_P),
        .SIZE_P         (2)
    ) rsp_buf (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .vld_i      (csr_req_vld),
        .rdy_i      (csr_req_rdy),
        .data_i     ({execute_if.data.uuid, execute_if.data.wid, execute_if.data.tmask, execute_if.data.PC, execute_if.data.rd, execute_if.data.wb, csr_read_data}),
        .data_o     ({commit_if.data.uuid,  commit_if.data.wid,  commit_if.data.tmask,  commit_if.data.PC,  commit_if.data.rd,  commit_if.data.wb,  commit_if.data.data}),
        .vld_o      (commit_if.vld),
        .rdy_o      (commit_if.rdy)
    );

endmodule
