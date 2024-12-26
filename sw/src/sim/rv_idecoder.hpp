#ifndef __RV_IDECODER_HPP__
#define __RV_IDECODER_HPP__

//#include "xrv1_soc.hpp"
#include "elf_loader.hpp"
#include "memory_base.hpp"

#include <cstdint>

//#define TOP_MODULE_NAME_TEST rv_idecoder_sim_top

class Vrv_idecoder_sim_top;
class VerilatedContext;
class VerilatedVcdC;

class rv_idecoder
{
public:

    rv_idecoder();
    ~rv_idecoder();

    void tick();
    bool check_m_ext_enabled() const;

public:
    Vrv_idecoder_sim_top* m_rtl = nullptr;
    VerilatedContext* m_ctx = nullptr;
    VerilatedVcdC* m_vcd = nullptr;

    int64_t m_ticks_passed_ = -1;
};

#endif /* __RV_IDECODER_HPP__ */
