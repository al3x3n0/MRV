#include "xrv1_top.hpp"
#include "Vxrv1_sim_top.h"
#include "Vxrv1_sim_top__Syms.h"


xrv1_top::xrv1_top(sc_module_name name) : sc_module(name)
{
    m_rtl = new Vxrv1_sim_top("Vxrv1_sim_top");
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
    m_rtl->__VlSymsp->TOP__xrv1_sim_top__tcm_i__itcm_i.write_u8(addr, data);
}

uint8_t xrv1_top::read_u8(uint32_t addr) {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__tcm_i__itcm_i.read_u8(addr);
}

bool xrv1_top::get_imem_resp_vld() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_imem_resp_vld();
}

uint32_t xrv1_top::get_imem_resp_data() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_imem_resp_data();
}

bool xrv1_top::get_imem_req_vld() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_imem_req_vld();
}

uint32_t xrv1_top::get_imem_req_addr() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_imem_req_addr();
}

uint32_t xrv1_top::get_ifetch_insn_data() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_ifetch_insn_data();
}

uint32_t xrv1_top::get_ifetch_insn_pc() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_ifetch_insn_pc();
}

bool xrv1_top::get_ifetch_insn_vld() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_ifetch_insn_vld();
}

uint32_t xrv1_top::get_if_dec_insn_data() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_if_dec_insn_data();
}

uint32_t xrv1_top::get_if_dec_insn_pc() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_if_dec_insn_pc();
}

bool xrv1_top::get_if_dec_insn_vld() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_if_dec_insn_vld();
}

bool xrv1_top::get_wb_data_vld() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_wb_data_vld();
}

uint32_t xrv1_top::get_wb_data() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_wb_data();
}

uint8_t xrv1_top::get_wb_rd_addr() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_wb_rd_addr();
}

bool xrv1_top::get_idecode_issue_vld() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_idecode_issue_vld();
}

uint8_t xrv1_top::get_idecode_itag() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_idecode_itag();
}

uint8_t xrv1_top::get_ret_retire_cnt() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_ret_retire_cnt();
}

uint8_t xrv1_top::get_iq_retire_itag() {
    return m_rtl->__VlSymsp->TOP__xrv1_sim_top__core_i.get_iq_retire_itag();
}
