#include <string>

#include "mrv1_soc.hpp"
#include "isa_sim/riscv_inst_dump.h"

// verilator includes
#include "Vmrv1_sim_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

mrv1_soc::mrv1_soc() : m_elf_loader(this) {
    const std::string prefix{VERILATOR_PREFIX};
    const std::string top_module{TOP_MODULE};

    // allocate verilated context
    m_ctx = new VerilatedContext;
    assert(m_ctx);

    // allocate rtl design
    m_rtl = new Vmrv1_sim_top(m_ctx, prefix.c_str());
    assert(m_rtl);

    Verilated::traceEverOn(true);
    m_vcd = new VerilatedVcdC;
    assert(m_vcd);
    m_rtl->trace(m_vcd, 99);

    // // set systemverilog scope to be able to access dpi functions
    // const std::string scope_name = prefix + "." + top_module;
    // auto* scope = svGetScopeFromName(scope_name.c_str());
    // assert(scope);
    // svSetScope(scope);

    m_ticks_passed_ = 0;
}

xrv1_soc::~xrv1_soc() {
    delete m_rtl;
    delete m_ctx;
    delete m_vcd;
}