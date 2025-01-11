#include <string>

#include "sim/single_core_soc.hpp"
#include "isa_sim/riscv_inst_dump.h"

char inst_decode_buffer [1024];

// verilator includes
#include "Vrv_soc_sim_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

single_core_soc::single_core_soc() : m_elf_loader(this) {
    const std::string prefix{VERILATOR_PREFIX};
    const std::string top_module{TOP_MODULE};

    // allocate verilated context
    m_ctx = new VerilatedContext;
    assert(m_ctx);

    // allocate rtl design
    m_rtl = new Vrv_soc_sim_top(m_ctx, prefix.c_str());
    assert(m_rtl);

    Verilated::traceEverOn(true);
    m_vcd = new VerilatedVcdC;
    assert(m_vcd);
    m_rtl->trace(m_vcd, 99);

    // set systemverilog scope to be able to access dpi functions
    const std::string scope_name = prefix + "." + top_module;
    auto* scope = svGetScopeFromName(scope_name.c_str());
    assert(scope);
    svSetScope(scope);

    m_ticks_passed_ = 0;
}

single_core_soc::~single_core_soc() {
    delete m_rtl;
    delete m_ctx;
    delete m_vcd;
}

void single_core_soc::write_u8(uint32_t addr, uint8_t data) {
    m_rtl->write_u8(addr, data);
}

uint8_t single_core_soc::read_u8(uint32_t addr) {
    char data;
    m_rtl->read_u8(addr, &data);
    return static_cast<uint8_t>(data);
}

uint32_t single_core_soc::get_ram_size_bits() const {
    int bits;
    m_rtl->get_ram_size_bits(&bits);
    return static_cast<uint32_t>(bits);
}

uint16_t single_core_soc::read_u16(uint32_t addr) {
    uint8_t bytes[2];
    for (int i = 0; i < 2; i++)
        bytes[i] = read_u8(addr + i);
    uint16_t res = ((bytes[1] << 8) | bytes[0]);
    return res;
}

uint32_t single_core_soc::read_u32(uint32_t addr) {
    uint8_t bytes[4];
    for (int i = 0; i < 4; i++)
        bytes[i] = read_u8(addr + i);
    uint32_t res = (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | (bytes[0]);
    return res;
}

void single_core_soc::release_reset() {
    m_rtl->rst_i = 0;
}

bool single_core_soc::get_reset_status() const {
    return m_rtl->rst_i;
}
    
void single_core_soc::tick() {
    m_rtl->clk_i = !m_rtl->clk_i;
    m_rtl->eval();
    if (m_vcd)
        m_vcd->dump(static_cast<uint64_t>(m_ticks_passed_));
    m_ticks_passed_++;

    m_rtl->clk_i = !m_rtl->clk_i;
    m_rtl->eval();
    if (m_vcd)
        m_vcd->dump(static_cast<uint64_t>(m_ticks_passed_));
    m_ticks_passed_++;
}

int64_t single_core_soc::get_ticks_number() const {
    return m_ticks_passed_;
}

bool single_core_soc::load_elf(const std::string& elf_path, int verbose_lvl) {
    uint32_t ram_max_addr = get_ram_size_bits();
    if (!m_elf_loader.load_data(elf_path.c_str(), ram_max_addr, verbose_lvl)) {
        std::cout << "Failed to load elf: " << elf_path << std::endl;
        return false;
    }
    return true;
}

bool single_core_soc::dump_signature(const std::string& path, int verbose_lvl) {
    auto sig_begin_addr = m_elf_loader.get_address_sig_begin();
    auto sig_end_addr = m_elf_loader.get_address_sig_end();
    if (sig_begin_addr == -1 || sig_end_addr == -1)
        return false;

    auto sig_begin = read_u32(sig_begin_addr);
    auto sig_end = read_u32(sig_end_addr);
    
    auto* fp = fopen(path.c_str(), "w");
    assert(fp);

    for (uint32_t addr = sig_begin; addr < sig_end; addr += 4) {
        auto val = read_u32(addr);
        if (verbose_lvl > 0)
            printf("Mem [0x%08x] : 0x%08x\n", addr, val);
        fprintf(fp, "%08x\n", val);
    }
    fclose(fp);
    return true;
}

bool single_core_soc::is_simulation_finished() const {
    return m_ctx->gotFinish();
}

uint32_t single_core_soc::get_reg_val_u32(uint32_t addr) const {
    int32_t val = 0;
    m_rtl->read_register(addr, &val);
    return static_cast<uint32_t>(val);
}

uint64_t single_core_soc::read_arch_reg(uint32_t addr) const {
    long long val = 0;
    m_rtl->soc_read_arch_register(0, 0, addr, &val);
    return static_cast<uint64_t>(val);
}

void single_core_soc::write_arch_reg(uint32_t addr, uint64_t val) {
    m_rtl->soc_write_arch_register(0, 0, addr, val);
}

bool single_core_soc::run_simulation(int num_cycles, int verbose_lvl) {
    if (m_vcd)
        m_vcd->open("out.vcd");

    uint32_t prev_fetch_addr = ~0u;

    // set reset to 1, clk to 0 and evaluate design
    m_rtl->clk_i = 0;
    m_rtl->rst_i = 1;
    tick();
    tick();
    
    // release design reset
    release_reset();

    // number of instructions retired
    uint32_t icnt = 0;
    // number of cycles passed
    uint32_t ccnt = 0;

    while (true) {
        // check if we need to stop simulation
        if (((ccnt >= num_cycles) && (num_cycles != -1)) || m_ctx->gotFinish()) {
            break;
        }
        on_simulation_step(verbose_lvl);
        tick();
        ccnt++;
    }

    printf("Simulation finished in %d cycles\n", ccnt);

    if (m_vcd)
        m_vcd->close();

    return true;
}

const char* single_core_soc::riscv_decode_instruction(uint32_t pc, uint32_t inst) {
    riscv_inst_decode(inst_decode_buffer, pc, inst);
    return inst_decode_buffer;
}

extern const char* riscv_decode_instruction(uint32_t pc, uint32_t inst) {
    return single_core_soc::riscv_decode_instruction(pc, inst);
}