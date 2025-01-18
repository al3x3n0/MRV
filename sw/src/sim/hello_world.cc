#include <cstdint>

volatile uint8_t* to_print = (uint8_t*)(0x1000);

int main() {
    for (const auto& c : "hello world") {
        *to_print = static_cast<uint8_t>(c);
    }
    asm volatile ("nop;nop;wfi");
    return 0;
}