#ifndef __XRV1_SOC_HPP__
#define __XRV1_SOC_HPP__

//#include "xrv1_soc.hpp"
#include "elf_loader.hpp"
#include "memory_base.hpp"

#include <cstdint>

class Vmrv1_sim_top;
class VerilatedContext;
class VerilatedVcdC;

class mrv1_soc: public Mem32Iface
{
public:

    mrv1_soc();
    ~mrv1_soc();

public:
    Vmrv1_sim_top* m_rtl = nullptr;
    VerilatedContext* m_ctx = nullptr;
    VerilatedVcdC* m_vcd = nullptr;

    // number of cycles passed from the simulation start
    int64_t m_ticks_passed_ = -1;
    // elf loader
    ElfLoaderArchTests m_elf_loader;
};

#endif /* __XRV1_SOC_HPP__ */
