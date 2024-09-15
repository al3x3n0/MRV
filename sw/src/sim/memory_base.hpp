#ifndef __XRV1_MEMORY_BASE_HPP__
#define __XRV1_MEMORY_BASE_HPP__

class Mem32Iface
{
public:
    //virtual bool create_memory(uint32_t addr, uint32_t size, uint8_t *mem = NULL) = 0;
    //virtual bool valid_addr(uint32_t addr) = 0;
    virtual void write_u8(uint32_t addr, uint8_t data) = 0;
    virtual uint8_t read_u8(uint32_t addr) = 0;
};

#endif /* __XRV1_MEMORY_BASE_HPP__ */
