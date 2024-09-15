#ifndef __XRV1_ELF_LOADER_4498_HPP__
#define __XRV1_ELF_LOADER_4498_HPP__

#include <elfio/elfio.hpp>
#include "memory_base.hpp"


class ElfLoader {
public:
    ElfLoader(const char* filename, Mem32Iface* mem_img);

    bool load();
private:
    ELFIO::elfio m_reader;
    const std::string m_filename;
    Mem32Iface* m_mem_img = nullptr;
    uint32_t m_entry_point = 0;
};

#endif /* __XRV1_ELF_LOADER_4498_HPP__ */
