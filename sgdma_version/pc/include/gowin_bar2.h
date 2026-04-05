#include <stdint.h>

typedef struct {
    volatile uint32_t addr_s2mm_lo; //* 0x00 - DDR3 Low Address
    volatile uint32_t addr_s2mm_hi; //* 0x04 - Source High Address
    volatile uint32_t length_s2mm;  //* 0x08 - Data length in bytes (run)
    volatile uint32_t rsv_s2mm;     //* 0x0C - Reserved

    volatile uint32_t addr_mm2s_lo; //* 0x10 - DDR3 Low Address
    volatile uint32_t addr_mm2s_hi; //* 0x14 - Source High Address
    volatile uint32_t length_mm2s;  //* 0x18 - Data length in bytes (run)
    volatile uint32_t rsv_mm2s;     //* 0x1C - Reserved
} GowinBar2;
