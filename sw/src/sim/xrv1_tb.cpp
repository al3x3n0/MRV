#include "xrv1_tb.hpp"
#include "elf_loader.hpp"

#include "Vxrv1_sim_top.h"
#include "Vxrv1_sim_top_xrv1_core.h"
#include "Vxrv1_sim_top__Syms.h"

#include "isa_sim/riscv_inst_dump.h"


xrv1_tb::xrv1_tb(sc_module_name name, const std::string elf_filename, uint64_t cycle_count) :
    sc_module(name),
    m_elf_filename(elf_filename),
    m_cycle_count(cycle_count)
{
    SC_CTHREAD(process, clk);

    m_dut = new xrv1_top("dut");
    m_dut->clk_i(clk);
    m_dut->rst_i(rst_i);
}

void xrv1_tb::process() {

    printf("================================================================================\n");
    ElfLoader elf_loader(m_elf_filename.c_str(), m_dut);
    if (!elf_loader.load()) {
        std::cout << "Failed to load!" << std::endl;
    }
    printf("================================================================================\n\n");

    char inst_dec_buf [1024];

    uint32_t cycle_count;
    uint32_t prev_fetch_addr = ~0u;

    rst_i.write(true);
    wait();
    rst_i.write(false);

    uint32_t icnt = 0;
    uint32_t ccnt = 0;

    while (true) {
        cycle_count += 1;
        if (cycle_count >= m_cycle_count && m_cycle_count != -1)
            break;

        if (m_dut->get_imem_resp_vld()) {
            uint32_t idata = m_dut->get_imem_resp_data();
            riscv_inst_decode(inst_dec_buf, prev_fetch_addr, idata);
            printf("[IF] %s\n", inst_dec_buf);
        }

        if (m_dut->get_imem_req_vld()) {
            prev_fetch_addr = m_dut->get_imem_req_addr();
            //printf("(IF->IMEM) 0x%x\n", prev_fetch_addr);
        }

        if (m_dut->get_ifetch_insn_vld()) {
            uint32_t i_data = m_dut->get_ifetch_insn_data();
            uint32_t i_pc = m_dut->get_ifetch_insn_pc();
            riscv_inst_decode(inst_dec_buf, i_pc, i_data);
            printf("(IF->DEC) %s\n", inst_dec_buf);
        }

        if (m_dut->get_if_dec_insn_vld()) {
            uint32_t i_data = m_dut->get_if_dec_insn_data();
            uint32_t i_pc = m_dut->get_if_dec_insn_pc();
            riscv_inst_decode(inst_dec_buf, i_pc, i_data);
            printf("[IF/DEC] %s", inst_dec_buf);
            if (m_dut->get_idecode_issue_vld()) {
                printf(" itag=%d", m_dut->get_idecode_itag());
            }
            printf("\n");
        }

	uint8_t ret_cnt = m_dut->get_ret_retire_cnt();
        if (ret_cnt > 0) {
            icnt += ret_cnt;
            printf("RETIRE(%d) %d itag=%d", ret_cnt, icnt, m_dut->get_iq_retire_itag());
            if (m_dut->get_wb_data_vld()) {
                uint8_t wb_rd = m_dut->get_wb_rd_addr();
                uint32_t wb_data = m_dut->get_wb_data();
                printf(" (WB) RF[%d] <- 0x%x", wb_rd, wb_data);
            }
            printf("\n");
        }

        wait();
        ccnt++;
        printf("================================================================================\n");
    }

    printf("IPC: %f\n", float(icnt)/float(ccnt));

    sc_stop();
}
