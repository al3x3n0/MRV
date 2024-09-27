#include <string>

#include "xrv1_soc.hpp"
#include "isa_sim/riscv_inst_dump.h"

// verilator includes
#include "Vxrv1_sim_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

xrv1_soc::xrv1_soc() : m_elf_loader(this) {
    const std::string prefix{VERILATOR_PREFIX};
    const std::string top_module{TOP_MODULE};

    // allocate verilated context
    m_ctx = new VerilatedContext;
    assert(m_ctx);

    // allocate rtl design
    m_rtl = new Vxrv1_sim_top(m_ctx, prefix.c_str());
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

xrv1_soc::~xrv1_soc() {
    delete m_rtl;
    delete m_ctx;
    delete m_vcd;
}

void xrv1_soc::write_u8(uint32_t addr, uint8_t data) {
    m_rtl->write_u8(addr, data);
}

uint8_t xrv1_soc::read_u8(uint32_t addr) {
    char data;
    m_rtl->read_u8(addr, &data);
    return static_cast<uint8_t>(data);
}

uint16_t xrv1_soc::read_u16(uint32_t addr) {
    uint8_t bytes[2];
    for (int i = 0; i < 2; i++)
        bytes[i] = read_u8(addr + i);
    uint16_t res = ((bytes[1] << 8) | bytes[0]);
    return res;
}

uint32_t xrv1_soc::read_u32(uint32_t addr) {
    uint8_t bytes[4];
    for (int i = 0; i < 4; i++)
        bytes[i] = read_u8(addr + i);
    uint32_t res = (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | (bytes[0]);
    return res;
}

bool xrv1_soc::get_imem_resp_vld() {
    char valid;
    m_rtl->get_imem_resp_vld(&valid);
    return valid;
}

uint32_t xrv1_soc::get_imem_resp_data() {
    int32_t data;
    m_rtl->get_imem_resp_data(&data);
    return static_cast<uint32_t>(data);
}

bool xrv1_soc::get_imem_req_vld() {
    char valid;
    m_rtl->get_imem_req_vld(&valid);
    return valid;
}

uint32_t xrv1_soc::get_imem_req_addr() {
    char valid;
    m_rtl->get_imem_req_vld(&valid);
    return valid;
}

uint32_t xrv1_soc::get_ifetch_insn_data() {
    int32_t data;
    m_rtl->get_ifetch_insn_data(&data);
    return static_cast<uint32_t>(data);
}

uint32_t xrv1_soc::get_ifetch_insn_pc() {
    int32_t pc;
    m_rtl->get_ifetch_insn_pc(&pc);
    return static_cast<uint32_t>(pc);
}

bool xrv1_soc::get_ifetch_insn_vld() {
    char valid;
    m_rtl->get_ifetch_insn_vld(&valid);
    return valid;
}

uint32_t xrv1_soc::get_if_dec_insn_data() {
    int32_t data;
    m_rtl->get_if_dec_insn_data(&data);
    return static_cast<uint32_t>(data);
}

uint32_t xrv1_soc::get_if_dec_insn_pc() {
    int32_t pc;
    m_rtl->get_if_dec_insn_pc(&pc);
    return static_cast<uint32_t>(pc);
}

bool xrv1_soc::get_if_dec_insn_vld() {
    char valid;
    m_rtl->get_if_dec_insn_vld(&valid);
    return valid;
}

bool xrv1_soc::get_wb_data_vld() {
    char valid;
    m_rtl->get_wb_data_vld(&valid);
    return valid;
}

uint32_t xrv1_soc::get_wb_data() {
    int32_t data;
    m_rtl->get_wb_data(&data);
    return static_cast<uint32_t>(data);
}

uint8_t xrv1_soc::get_wb_rd_addr() {
    char addr;
    m_rtl->get_wb_rd_addr(&addr);
    return static_cast<uint8_t>(addr);
}

bool xrv1_soc::get_idecode_issue_vld() {
    char valid;
    m_rtl->get_idecode_issue_vld(&valid);
    return valid;
}

uint8_t xrv1_soc::get_idecode_itag() {
    char itag;
    m_rtl->get_idecode_itag(&itag);
    return static_cast<uint8_t>(itag);
}

uint8_t xrv1_soc::get_ret_retire_cnt() {
    char cnt;
    m_rtl->get_ret_retire_cnt(&cnt);
    return static_cast<uint8_t>(cnt);
}

uint8_t xrv1_soc::get_iq_retire_itag() {
    char itag;
    m_rtl->get_iq_retire_itag(&itag);
    return static_cast<uint8_t>(itag);
}


void xrv1_soc::release_reset() {
    m_rtl->rst_i = 0;
}

bool xrv1_soc::get_reset_status() const {
    return m_rtl->rst_i;
}
    
void xrv1_soc::tick() {
    m_rtl->clk_i = !m_rtl->clk_i;
    m_rtl->eval();
    m_rtl->clk_i = !m_rtl->clk_i;
    m_rtl->eval();
    if (m_vcd)
        m_vcd->dump(static_cast<uint64_t>(m_ticks_passed_));
    m_ticks_passed_++;
}

int64_t xrv1_soc::get_ticks_number() const {
    return m_ticks_passed_;
}

bool xrv1_soc::load_elf(const std::string& elf_path, int verbose_lvl) {
    if (!m_elf_loader.load_data(elf_path.c_str(), verbose_lvl)) {
        std::cout << "Failed to load elf: " << elf_path << std::endl;
        return false;
    }
    return true;
}

bool xrv1_soc::dump_signature(const std::string& path, int verbose_lvl) {
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

bool xrv1_soc::is_simulation_finished() const {
    return m_ctx->gotFinish();
}

bool xrv1_soc::run_simulation(int num_cycles, int verbose_lvl) {
    char inst_dec_buf [1024];

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

        if (get_imem_resp_vld()) {
            uint32_t idata = get_imem_resp_data();
            riscv_inst_decode(inst_dec_buf, prev_fetch_addr, idata);
            if (verbose_lvl > 0)
                printf("[IF] %s\n", inst_dec_buf);
        }

        if (get_imem_req_vld()) {
            prev_fetch_addr = get_imem_req_addr();
            //printf("(IF->IMEM) 0x%x\n", prev_fetch_addr);
        }

        if (get_ifetch_insn_vld()) {
            uint32_t i_data = get_ifetch_insn_data();
            uint32_t i_pc = get_ifetch_insn_pc();
            riscv_inst_decode(inst_dec_buf, i_pc, i_data);
            if (verbose_lvl > 0)
                printf("(IF->DEC) %s\n", inst_dec_buf);
        }

        if (get_if_dec_insn_vld()) {
            uint32_t i_data = get_if_dec_insn_data();
            uint32_t i_pc = get_if_dec_insn_pc();
            riscv_inst_decode(inst_dec_buf, i_pc, i_data);
            if (verbose_lvl > 0)
                printf("[IF/DEC] %s", inst_dec_buf);
            if (get_idecode_issue_vld()) {
                if (verbose_lvl > 0)
                    printf(" itag=%d", get_idecode_itag());
            }
            if (verbose_lvl > 0)
                printf("\n");
        }

	    uint8_t ret_cnt = get_ret_retire_cnt();
        if (ret_cnt > 0) {
            icnt += ret_cnt;
            if (verbose_lvl > 0)
                printf("RETIRE(%d) %d itag=%d", ret_cnt, icnt, get_iq_retire_itag());
            if (get_wb_data_vld()) {
                uint8_t wb_rd = get_wb_rd_addr();
                uint32_t wb_data = get_wb_data();
                if (verbose_lvl > 0)
                    printf(" (WB) RF[%d] <- 0x%x", wb_rd, wb_data);
            }
            if (verbose_lvl > 0)
                printf("\n");
        }
        if (verbose_lvl > 0)
            printf("================================================================================\n");

        tick();
        ccnt++;
    }

    printf("Simulation finished in %d cycles\n", ccnt);

    if (m_vcd)
        m_vcd->close();

    return true;
}