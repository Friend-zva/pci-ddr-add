#include <stdint.h>

#ifndef GOWIN_BAR2_H
#define GOWIN_BAR2_H

#define BAR2_SIZE (1024 * 2)

// For control register (0x00)
#define BAR2_PCIE_WR_START (1 << 0) // h2c
#define BAR2_PCIE_RD_START (1 << 1) // c2h
#define BAR2_LAD_START (1 << 2)
#define BAR2_LAD_STOP (1 << 3)

#define BAR2_LAD_DONE (1 << 7)
#define BAR2_DDR_STATE (1 << 8)

typedef struct {
    volatile uint32_t ctrl;      //* 0x00 - Control (RW)
    volatile uint32_t status;    //* 0x04 - Status (RO)
    volatile uint32_t rsv_08[2]; //* 0x08-0x0F - Reserved

    volatile uint32_t addr_ddr_h2c_lo; //* 0x10 - PCIe Write Low Address
    volatile uint32_t addr_ddr_h2c_hi; //* 0x14 - PCIe Write High Address
    volatile uint32_t leng_ddr_h2c;    //* 0x18 - PCIe Write Length

    volatile uint32_t addr_ddr_c2h_lo; //* 0x1C - PCIe Read Low Address
    volatile uint32_t addr_ddr_c2h_hi; //* 0x20 - PCIe Read High Address
    volatile uint32_t leng_ddr_c2h;    //* 0x24 - PCIe Read Length

    volatile uint32_t rsv_28[2]; //* 0x28-0x2F - Reserved

    volatile uint32_t addr_lad_rd_lo; //* 0x30 - Logic Adder Read Low Address
    volatile uint32_t addr_lad_rd_hi; //* 0x34 - Logic Adder Read High Address
    volatile uint32_t addr_lad_wr_lo; //* 0x38 - Logic Adder Write Low Address
    volatile uint32_t addr_lad_wr_hi; //* 0x3C - Logic Adder Write High Address
    volatile uint32_t leng_lad;       //* 0x40 - Logic Adder Length
} GowinBar2;

#endif // GOWIN_BAR2_H
