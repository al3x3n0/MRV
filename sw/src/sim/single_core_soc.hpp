#ifndef __SINGLE_CORE_SOC_HPP__
#define __SINGLE_CORE_SOC_HPP__

#include "sim/elf_loader.hpp"
#include "sim/memory_base.hpp"

#include <cstdint>

class Vrv_soc_sim_top;
class VerilatedContext;
class VerilatedVcdC;

class single_core_soc: public Mem32Iface
{
public:

    single_core_soc();
    virtual ~single_core_soc();

    void write_u8(uint32_t addr, uint8_t data);
    uint8_t read_u8(uint32_t addr);
    uint16_t read_u16(uint32_t addr);
    uint32_t read_u32(uint32_t addr);

    uint32_t get_ram_size_bits() const;

    uint32_t get_reg_val_u32(uint32_t addr) const;

    uint64_t read_arch_reg(uint32_t addr) const;
    void write_arch_reg(uint32_t addr, uint64_t val);

    // release reset for design
    void release_reset();
    // get reset status
    bool get_reset_status() const;
    // do one tick
    void tick();
    // get number of ticks passed
    int64_t get_ticks_number() const;
    // load elf
    bool load_elf(const std::string& elf_path, int verbose_lvl);
    // runs simulation
    bool run_simulation(int num_cycles, int verbose_lvl = 0);
    // dump arch test signature
    bool dump_signature(const std::string& path, int verbose_lvl);
    // check if simulation is really finished
    bool is_simulation_finished() const;

protected:
    virtual void on_simulation_step(int verbose_lvl) = 0;

public:
    Vrv_soc_sim_top* m_rtl = nullptr;
    VerilatedContext* m_ctx = nullptr;
    VerilatedVcdC* m_vcd = nullptr;

    // number of cycles passed from the simulation start
    int64_t m_ticks_passed_ = -1;
    // elf loader
    ElfLoaderArchTests m_elf_loader;

protected:
    uint64_t m_retired_icnt = 0;
};

#endif /* __SINGLE_CORE_SOC_HPP__ */
