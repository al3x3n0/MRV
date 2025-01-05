#include <string>

#include "sim/xrv1/xrv1_soc.hpp"
#include "isa_sim/riscv_inst_dump.h"

// verilator includes
#include "Vrv_soc_sim_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

xrv1_soc::xrv1_soc() {
}

xrv1_soc::~xrv1_soc() {
}

bool xrv1_soc::get_imem_resp_vld() {
    char valid;
    m_rtl->get_imem_resp_vld(&valid);
    return valid;
}

uint32_t xrv1_soc::get_imem_resp_data() {
    int32_t data;
    m_rtl->get_imem_resp_data(&data);
    return static_cast<uint32_t>(data);
}

bool xrv1_soc::get_imem_req_vld() {
    char valid;
    m_rtl->get_imem_req_vld(&valid);
    return valid;
}

uint32_t xrv1_soc::get_imem_req_addr() {
    char valid;
    m_rtl->get_imem_req_vld(&valid);
    return valid;
}

uint32_t xrv1_soc::get_ifetch_insn_data() {
    int32_t data;
    m_rtl->get_ifetch_insn_data(&data);
    return static_cast<uint32_t>(data);
}

uint32_t xrv1_soc::get_ifetch_insn_pc() {
    int32_t pc;
    m_rtl->get_ifetch_insn_pc(&pc);
    return static_cast<uint32_t>(pc);
}

bool xrv1_soc::get_ifetch_insn_vld() {
    char valid;
    m_rtl->get_ifetch_insn_vld(&valid);
    return valid;
}

uint32_t xrv1_soc::get_if_dec_insn_data() {
    int32_t data;
    m_rtl->get_if_dec_insn_data(&data);
    return static_cast<uint32_t>(data);
}

uint32_t xrv1_soc::get_if_dec_insn_pc() {
    int32_t pc;
    m_rtl->get_if_dec_insn_pc(&pc);
    return static_cast<uint32_t>(pc);
}

bool xrv1_soc::get_if_dec_insn_vld() {
    char valid;
    m_rtl->get_if_dec_insn_vld(&valid);
    return valid;
}

bool xrv1_soc::get_wb_data_vld() {
    char valid;
    m_rtl->get_wb_data_vld(&valid);
    return valid;
}

uint32_t xrv1_soc::get_wb_data() {
    int32_t data;
    m_rtl->get_wb_data(&data);
    return static_cast<uint32_t>(data);
}

uint8_t xrv1_soc::get_wb_rd_addr() {
    char addr;
    m_rtl->get_wb_rd_addr(&addr);
    return static_cast<uint8_t>(addr);
}

bool xrv1_soc::get_idecode_issue_vld() {
    char valid;
    m_rtl->get_idecode_issue_vld(&valid);
    return valid;
}

uint8_t xrv1_soc::get_idecode_itag() {
    char itag;
    m_rtl->get_idecode_itag(&itag);
    return static_cast<uint8_t>(itag);
}

uint8_t xrv1_soc::get_ret_retire_cnt() {
    char cnt;
    m_rtl->get_ret_retire_cnt(&cnt);
    return static_cast<uint8_t>(cnt);
}

uint8_t xrv1_soc::get_iq_retire_itag() {
    char itag;
    m_rtl->get_iq_retire_itag(&itag);
    return static_cast<uint8_t>(itag);
}

void xrv1_soc::on_simulation_step(int verbose_lvl) {
    char inst_dec_buf [1024];

    if (get_imem_resp_vld()) {
        uint32_t idata = get_imem_resp_data();
        riscv_inst_decode(inst_dec_buf, m_prev_fetch_addr, idata);
        if (verbose_lvl > 0)
            printf("[IF] %s\n", inst_dec_buf);
    }

    if (get_imem_req_vld()) {
        m_prev_fetch_addr = get_imem_req_addr();
    }

    if (get_ifetch_insn_vld()) {
        uint32_t i_data = get_ifetch_insn_data();
        uint32_t i_pc = get_ifetch_insn_pc();
        riscv_inst_decode(inst_dec_buf, i_pc, i_data);
        if (verbose_lvl > 0)
            printf("(IF->DEC) %s\n", inst_dec_buf);
    }

    if (get_if_dec_insn_vld()) {
        uint32_t i_data = get_if_dec_insn_data();
        uint32_t i_pc = get_if_dec_insn_pc();
        riscv_inst_decode(inst_dec_buf, i_pc, i_data);
        if (verbose_lvl > 0)
            printf("[IF/DEC] %s", inst_dec_buf);
        if (get_idecode_issue_vld()) {
            if (verbose_lvl > 0)
                printf(" itag=%d", get_idecode_itag());
        }
        if (verbose_lvl > 0)
            printf("\n");
    }

    uint8_t ret_cnt = get_ret_retire_cnt();
    if (ret_cnt > 0) {
        m_retired_icnt += ret_cnt;
        if (verbose_lvl > 0)
            printf("RETIRE(%d) %" PRIx64 " itag=%d", ret_cnt, m_retired_icnt, get_iq_retire_itag());
        if (get_wb_data_vld()) {
            uint8_t wb_rd = get_wb_rd_addr();
            uint32_t wb_data = get_wb_data();
            if (verbose_lvl > 0)
                printf(" (WB) RF[%d] <- 0x%x", wb_rd, wb_data);
        }
        if (verbose_lvl > 0)
            printf("\n");
    }
    if (verbose_lvl > 0) {
        printf("================================================================================\n");
    }
}