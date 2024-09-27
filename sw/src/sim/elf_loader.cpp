#include "elf_loader.hpp"
#include <cassert>


ElfLoader::ElfLoader(const char* filename, Mem32Iface* mem_img) :
    m_filename(filename),
    m_mem_img(mem_img)
{
}


bool ElfLoader::load(int verbose_lvl) {
    assert(!m_filename.empty());
    int byte_written = 0;

    if (!m_reader.load(m_filename)) {
        return false;
    }

    if (m_reader.get_class() != ELFIO::ELFCLASS32) {
        return false;
    }

    m_entry_point = m_reader.get_entry();
    if (verbose_lvl > 0)
        printf("Entry point: 0x%x\n", m_entry_point);

    for (size_t i = 0; i < m_reader.sections.size(); i++) {
        ELFIO::section* sec = m_reader.sections[i];
        uint32_t sec_size = sec->get_size();
        uint32_t sec_addr = sec->get_address();
        if ((sec->get_flags() & ELFIO::SHF_ALLOC) && sec_size > 0) {
            const char* sec_data = sec->get_data();
            if (verbose_lvl > 1)
                printf("Memory: 0x%x - 0x%x (Size=%dKB)\n", sec_addr, sec_addr + sec_size - 1, sec_size / 1024);

            if (sec->get_type() == ELFIO::SHT_PROGBITS) {
                for (uint32_t j = 0; j < sec_size; j++) {
                    if (verbose_lvl > 2)
                        printf("MEM[0x%x] <- 0x%x\n", sec_addr +j , static_cast<uint8_t>(sec_data[j]));
                    m_mem_img->write_u8(sec_addr + j, sec_data[j]);
                    byte_written++;
                }
            }
        }
    }
    return true;
}

ElfLoaderArchTests::ElfLoaderArchTests(Mem32Iface* mem_img) :
    ElfLoader("", mem_img)
{
}

bool ElfLoaderArchTests::load_data(const char* filename, int verbose_lvl) {
    m_filename = std::string(filename);
    const auto res = load(verbose_lvl);
    if (res)
        fill_section_addresses(verbose_lvl);
    return res;
}
    
uint32_t ElfLoaderArchTests::get_address_sig_begin() const {
    return m_section_addr_sig_begin;
}

uint32_t ElfLoaderArchTests::get_address_sig_end() const {
    return m_section_addr_sig_end;
}

uint32_t ElfLoaderArchTests::get_address_tohost() const {
    return m_section_addr_tohost;
}

uint32_t ElfLoaderArchTests::get_address_fromhost() const {
    return m_section_addr_fromhost;
}

void ElfLoaderArchTests::fill_section_addresses(int verbose_lvl) {
    for (size_t i = 0; i < m_reader.sections.size(); i++) {
        ELFIO::section* sec = m_reader.sections[i];
        const std::string sec_name{sec->get_name()};
        
        // handle "fromhost" section
        if (m_section_name_fromhost == sec_name) {
            m_section_addr_fromhost = sec->get_address();
            if (verbose_lvl > 1)
                printf("Found address of \"%s\" section: 0x%x\n", m_section_name_fromhost.c_str(), m_section_addr_fromhost);
        }
        // handle "tohost" section
        if (m_section_name_tohost == sec_name) {
            m_section_addr_tohost = sec->get_address();
            if (verbose_lvl > 1)
                printf("Found address of \"%s\" section: 0x%x\n", m_section_name_fromhost.c_str(), m_section_addr_tohost);
        }
        // handle "sig_begin" section
        if (m_section_name_sig_begin == sec_name) {
            m_section_addr_sig_begin = sec->get_address();
            if (verbose_lvl > 1)
                printf("Found address of \"%s\" section: 0x%x\n", m_section_name_fromhost.c_str(), m_section_addr_sig_begin);
        }
        // handle "sig_end" section
        if (m_section_name_sig_end == sec_name) {
            m_section_addr_sig_end = sec->get_address();
            if (verbose_lvl > 1)
                printf("Found address of \"%s\" section: 0x%x\n", m_section_name_fromhost.c_str(), m_section_addr_sig_end);
        }
    }
}