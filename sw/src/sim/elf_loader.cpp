#include "elf_loader.hpp"


ElfLoader::ElfLoader(const char* filename, Mem32Iface* mem_img) :
    m_filename(filename),
    m_mem_img(mem_img)
{
}


bool ElfLoader::load() {
    if (!m_reader.load(m_filename)) {
        return false;
    }

    if (m_reader.get_class() != ELFCLASS32) {
        return false;
    }

    m_entry_point = m_reader.get_entry();
    printf("Entry point: 0x%x\n", m_entry_point);

    for (size_t i = 0; i < m_reader.sections.size(); i++) {
        ELFIO::section* sec = m_reader.sections[i];
        uint32_t sec_size = sec->get_size();
        uint32_t sec_addr = sec->get_address();
        if ((sec->get_flags() & SHF_ALLOC) && sec_size > 0) {
            const char* sec_data = sec->get_data();
            printf("Memory: 0x%x - 0x%x (Size=%dKB)\n", sec_addr, sec_addr + sec_size - 1, sec_size / 1024);

            if (sec->get_type() == SHT_PROGBITS) {
                for (uint32_t j = 0; j < sec_size; j++) {
			printf("MEM[0x%x] <- 0x%x\n", sec_addr +j , sec_data[j]);
                    m_mem_img->write_u8(sec_addr + j, sec_data[j]);
                }
            }
        }
    }
    return true;
}
