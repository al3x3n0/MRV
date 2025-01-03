#ifndef __XRV1_SOC_HPP__
#define __XRV1_SOC_HPP__

#include "sim/single_core_soc.hpp"
#include <cstdint>


class xrv1_soc: public single_core_soc
{
public:

    xrv1_soc();
    ~xrv1_soc();

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

protected:
    void on_simulation_step(int verbose_lvl);

private:
    uint64_t m_prev_fetch_addr = 0;
};

#endif /* __XRV1_SOC_HPP__ */
