#ifndef __XRV1_TOP_21700_HPP__
#define __XRV1_TOP_21700_HPP__

#include <systemc.h>
#include "memory_base.hpp"

class Vxrv1_sim_top;
class VerilatedVcdC;

class xrv1_top: public sc_module,
                public Mem32Iface
{
public:
    sc_in<bool> clk_i;
    sc_in<bool> rst_i;

    SC_HAS_PROCESS(xrv1_top);
    xrv1_top(sc_module_name name);

    void async_outputs(void);

    bool get_imem_req_vld();
    uint32_t get_imem_req_addr();

    bool get_imem_resp_vld();
    uint32_t get_imem_resp_data();

    bool get_ifetch_insn_vld();
    uint32_t get_ifetch_insn_data();
    uint32_t get_ifetch_insn_pc();

    bool get_if_dec_insn_vld();
    uint32_t get_if_dec_insn_pc();
    uint32_t get_if_dec_insn_data();

    bool get_wb_data_vld();
    uint32_t get_wb_data();
    uint8_t get_wb_rd_addr();

    bool get_idecode_issue_vld();
    uint8_t get_idecode_itag();

    uint8_t get_ret_retire_cnt();
    uint8_t get_iq_retire_itag();

    void write_u8(uint32_t addr, uint8_t data);
    uint8_t read_u8(uint32_t addr);

public:
    Vxrv1_sim_top* m_rtl = nullptr;
#if 0
    VerilatedVcdC  * m_vcd;
#endif
private:
    sc_signal<bool> m_clk_i;
    sc_signal<bool> m_rst_i;
};

#endif /* __XRV1_TOP_21700_HPP__ */
