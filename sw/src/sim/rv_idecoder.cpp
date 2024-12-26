#include <string>

#include "rv_idecoder.hpp"

// verilator includes
#include "Vrv_idecoder_sim_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

rv_idecoder::rv_idecoder() {
    const std::string prefix{VERILATOR_PREFIX};
    const std::string top_module{TOP_MODULE};

    // allocate verilated context
    m_ctx = new VerilatedContext;
    assert(m_ctx);

    // allocate rtl design
    m_rtl = new Vrv_idecoder_sim_top(m_ctx, prefix.c_str());
    assert(m_rtl);

    Verilated::traceEverOn(true);
    m_vcd = new VerilatedVcdC;
    assert(m_vcd);
    m_rtl->trace(m_vcd, 99);
    // to print all available scopes
    //Verilated::scopesDump();

    // set systemverilog scope to be able to access dpi functions
    const std::string scope_name = prefix + "." + top_module;
    auto* scope = svGetScopeFromName(scope_name.c_str());
    assert(scope);
    svSetScope(scope);

    m_ticks_passed_ = 0;
}

rv_idecoder::~rv_idecoder() {
    delete m_rtl;
    delete m_ctx;
    delete m_vcd;
}

    
void rv_idecoder::tick() {
    m_rtl->clk_i = !m_rtl->clk_i;
    m_rtl->eval();
    m_rtl->clk_i = !m_rtl->clk_i;
    m_rtl->eval();
    if (m_vcd)
        m_vcd->dump(static_cast<uint64_t>(m_ticks_passed_));
    m_ticks_passed_++;
}

bool rv_idecoder::check_m_ext_enabled() const {
    char valid;
    m_rtl->check_m_ext_enabled(&valid);
    return valid;
}
