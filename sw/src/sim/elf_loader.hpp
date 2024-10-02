#ifndef __XRV1_ELF_LOADER_4498_HPP__
#define __XRV1_ELF_LOADER_4498_HPP__

#include <elfio/elfio.hpp>
#include "memory_base.hpp"

class ElfLoaderArchTests;

class ElfLoader {
public:
    ElfLoader(const char* filename, Mem32Iface* mem_img);

    bool load(int verbose_lvl = 0);
private:
    ELFIO::elfio m_reader;
    std::string m_filename;
    Mem32Iface* m_mem_img = nullptr;
    uint32_t m_entry_point = 0;

    friend class ElfLoaderArchTests;
};

class ElfLoaderArchTests : public ElfLoader {
public:
    ElfLoaderArchTests(Mem32Iface* mem_img);
    ~ElfLoaderArchTests() = default;

    // load elf binary data to memory interface
    bool load_data(const char* filename, uint32_t ram_max_addr, int verbose_lvl);
    
    // get address of "sig_begin" section
    uint32_t get_address_sig_begin() const;
    // get address of "sig_end" section
    uint32_t get_address_sig_end() const;
    // get address of "tohost" section
    uint32_t get_address_tohost() const;
    // get address of "fromhost" section
    uint32_t get_address_fromhost() const;
private:
    // for riscv arch tests we define several sections to interact
    // between host and dut
    
    // section "tohost" is used to pass return value to host
    const std::string m_section_name_tohost{".tohost"};
    uint32_t m_section_addr_tohost = -1;
    // section "fromhost" is used to pass some value to dut
    const std::string m_section_name_fromhost{".fromhost"};
    uint32_t m_section_addr_fromhost = -1;
    // section "sig_begin" is used to show where the test signature starts
    const std::string m_section_name_sig_begin{".sig_begin"};
    uint32_t m_section_addr_sig_begin = -1;
    // section "sig_end" is used to show where the test signature ends
    const std::string m_section_name_sig_end{".sig_end"};
    uint32_t m_section_addr_sig_end = -1;

    // go through all sections and try to find corresponding addresses
    // for given sections
    void fill_section_addresses(int verbose_lvl);
    // go through all sections and compare section max addres and
    // max available ram
    bool check_elf_against_ram_size(uint32_t ram_max_addr) const;
};

#endif /* __XRV1_ELF_LOADER_4498_HPP__ */
