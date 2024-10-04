#ifndef __XRV1_SOC_HPP__
#define __XRV1_SOC_HPP__

#include "xrv1_soc.hpp"
#include "elf_loader.hpp"
#include "memory_base.hpp"

#include <cstdint>

class Vxrv1_sim_top;
class VerilatedContext;
class VerilatedVcdC;

class xrv1_soc: public Mem32Iface
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

    void write_u8(uint32_t addr, uint8_t data);
    uint8_t read_u8(uint32_t addr);
    uint16_t read_u16(uint32_t addr);
    uint32_t read_u32(uint32_t addr);

    uint32_t get_ram_size_bits() const;

    uint32_t get_reg_val_u32(uint32_t addr) const;


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

public:
    Vxrv1_sim_top* m_rtl = nullptr;
    VerilatedContext* m_ctx = nullptr;
    VerilatedVcdC* m_vcd = nullptr;

    // number of cycles passed from the simulation start
    int64_t m_ticks_passed_ = -1;
    // elf loader
    ElfLoaderArchTests m_elf_loader;
};

#endif /* __XRV1_SOC_HPP__ */
