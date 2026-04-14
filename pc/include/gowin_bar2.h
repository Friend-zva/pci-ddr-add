#include <stdint.h>

#ifndef GOWIN_BAR2_H
#define GOWIN_BAR2_H

#define BAR2_SIZE (1024 * 2)

// For control register (0x00)
#define BAR2_PCIE_WR_START (1 << 0) // h2c
#define BAR2_PCIE_WR_STOP (1 << 1)
#define BAR2_PCIE_RD_START (1 << 2) // c2h
#define BAR2_PCIE_RD_STOP (1 << 3)
#define BAR2_LAD_START (1 << 4) // adder
#define BAR2_LAD_STOP (1 << 5)
#define BAR2_LAD_DONE (1 << 6)

typedef struct __attribute__((packed, aligned(32))) {
    volatile uint32_t ctrl;      //* 0x000 - Control (RW)
    volatile uint32_t status;    //* 0x004 - Status (RO)
    volatile uint32_t rsv_08[2]; //* 0x008-0x00F - Reserved

    volatile uint32_t addr_ddr_h2c; //* 0x010 - PCIe Write Address (RW)
    volatile uint32_t leng_ddr_h2c; //* 0x014 - PCIe Write Length (RW)
    volatile uint32_t rsv_18[2];    //* 0x018-0x01F - Reserved

    volatile uint32_t addr_ddr_c2h; //* 0x020 - PCIe Read Address (RW)
    volatile uint32_t leng_ddr_c2h; //* 0x024 - PCIe Read Length (RW)
    volatile uint32_t rsv_28[2];    //* 0x028-0x02F - Reserved

    volatile uint32_t addr_lad_rd; //* 0x030 - Logic Adder Read  Address (RW)
    volatile uint32_t addr_lad_wr; //* 0x034 - Logic Adder Write Address (RW)
    volatile uint32_t leng_lad;    //* 0x038 - Logic Adder Length (RW)

    volatile uint32_t rsv_3c[497]; //* 0x03C-0x7FF - Reserved
} GowinBar2;

#endif // GOWIN_BAR2_H
