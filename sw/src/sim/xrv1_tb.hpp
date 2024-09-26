#ifndef __XRV1_TB_7612_HPP__
#define __XRV1_TB_7612_HPP__

#include <systemc.h>
#include "verilated.h"
#include "verilated_vcd_sc.h"

#include "xrv1_top.hpp"


class xrv1_tb : public sc_module {
public:
    sc_in<bool> clk;
    sc_in<bool> rst;

    sc_signal<bool> rst_i;

    xrv1_top* m_dut = nullptr;
    VerilatedContext* m_ctx = nullptr;

    SC_HAS_PROCESS(xrv1_tb);
    xrv1_tb(sc_module_name name, const std::string elf_filename, uint64_t cycle_count);

    void process();

protected:
    const std::string m_elf_filename;
    uint64_t m_cycle_count;
    VerilatedVcdC* m_verilate_vcd = nullptr;
};


#endif /* __XRV1_TB_7612_HPP__ */
