#include "xrv1_top.hpp"
#include "Vxrv1_sim_top.h"
#include "Vxrv1_sim_top__Syms.h"

xrv1_top::xrv1_top(sc_module_name name) : sc_module(name)
{
    m_rtl = new Vxrv1_sim_top("Vxrv1_sim_top");

    auto* scope = svGetScopeFromName("tb.dut.Vxrv1_sim_top.xrv1_sim_top");
    assert(scope);
    svSetScope(scope);

    m_rtl->clk_i(m_clk_i);
    m_rtl->rst_i(m_rst_i);

    SC_METHOD(async_outputs);
    sensitive << clk_i;
    sensitive << rst_i;
}

void xrv1_top::async_outputs(void) {
    m_clk_i.write(clk_i.read());
    m_rst_i.write(rst_i.read());
}

void xrv1_top::write_u8(uint32_t addr, uint8_t data) {
    m_rtl->write_u8(addr, data);
}

uint8_t xrv1_top::read_u8(uint32_t addr) {
    char data;
    m_rtl->read_u8(addr, &data);
    return static_cast<uint8_t>(data);
}

bool xrv1_top::get_imem_resp_vld() {
    char valid;
    m_rtl->get_imem_resp_vld(&valid);
    return valid;
}

uint32_t xrv1_top::get_imem_resp_data() {
    int32_t data;
    m_rtl->get_imem_resp_data(&data);
    return static_cast<uint32_t>(data);
}

bool xrv1_top::get_imem_req_vld() {
    char valid;
    m_rtl->get_imem_req_vld(&valid);
    return valid;
}

uint32_t xrv1_top::get_imem_req_addr() {
    char valid;
    m_rtl->get_imem_req_vld(&valid);
    return valid;
}

uint32_t xrv1_top::get_ifetch_insn_data() {
    int32_t data;
    m_rtl->get_ifetch_insn_data(&data);
    return static_cast<uint32_t>(data);
}

uint32_t xrv1_top::get_ifetch_insn_pc() {
    int32_t pc;
    m_rtl->get_ifetch_insn_pc(&pc);
    return static_cast<uint32_t>(pc);
}

bool xrv1_top::get_ifetch_insn_vld() {
    char valid;
    m_rtl->get_ifetch_insn_vld(&valid);
    return valid;
}

uint32_t xrv1_top::get_if_dec_insn_data() {
    int32_t data;
    m_rtl->get_if_dec_insn_data(&data);
    return static_cast<uint32_t>(data);
}

uint32_t xrv1_top::get_if_dec_insn_pc() {
    int32_t pc;
    m_rtl->get_if_dec_insn_pc(&pc);
    return static_cast<uint32_t>(pc);
}

bool xrv1_top::get_if_dec_insn_vld() {
    char valid;
    m_rtl->get_if_dec_insn_vld(&valid);
    return valid;
}

bool xrv1_top::get_wb_data_vld() {
    char valid;
    m_rtl->get_wb_data_vld(&valid);
    return valid;
}

uint32_t xrv1_top::get_wb_data() {
    int32_t data;
    m_rtl->get_wb_data(&data);
    return static_cast<uint32_t>(data);
}

uint8_t xrv1_top::get_wb_rd_addr() {
    char addr;
    m_rtl->get_wb_rd_addr(&addr);
    return static_cast<uint8_t>(addr);
}

bool xrv1_top::get_idecode_issue_vld() {
    char valid;
    m_rtl->get_idecode_issue_vld(&valid);
    return valid;
}

uint8_t xrv1_top::get_idecode_itag() {
    char itag;
    m_rtl->get_idecode_itag(&itag);
    return static_cast<uint8_t>(itag);
}

uint8_t xrv1_top::get_ret_retire_cnt() {
    char cnt;
    m_rtl->get_ret_retire_cnt(&cnt);
    return static_cast<uint8_t>(cnt);
}

uint8_t xrv1_top::get_iq_retire_itag() {
    char itag;
    m_rtl->get_iq_retire_itag(&itag);
    return static_cast<uint8_t>(itag);
}
