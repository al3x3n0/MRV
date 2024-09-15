#include "xrv1_rst_gen.hpp"
#include "xrv1_tb.hpp"

#include "CLI/CLI.hpp"


static xrv1_tb* tb = nullptr;


int sc_main(int argc, char** argv) {

    CLI::App app("xrv1_tb");
    std::string elf_filename;
    uint64_t cycle_count = 100;
    app.add_option("-e,--elf", elf_filename, "Executable elf file")
           ->required()
           ->check(CLI::ExistingFile);
    app.add_option("-c,--cycles", cycle_count, "Cycle count to run");
    CLI11_PARSE(app, argc, argv);

    sc_clock clk ("clk_i", 10, SC_NS);

    xrv1_rst_gen rst_gen("rst_i");
    rst_gen.clk(clk);

    // Testbench
    tb = new xrv1_tb ("tb", elf_filename, cycle_count);
    tb->clk(clk);
    tb->rst(rst_gen.rst);

    sc_start();

    return 0;
}
