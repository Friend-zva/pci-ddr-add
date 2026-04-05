#include <stdint.h>

// For control register (0x00)
#define BAR2_CTRL_PCIE_RD_START (1 << 0)
#define BAR2_CTRL_PCIE_WR_START (1 << 1)
#define BAR2_CTRL_LAD_START (1 << 2)
#define BAR2_CTRL_LAD_STOP (1 << 3)

#define BAR2_STATUS_LAD_DONE (1 << 7)

typedef struct {
    volatile uint32_t ctrl;      //* 0x00 - Control (RW)
    volatile uint32_t status;    //* 0x04 - Status (RO)
    volatile uint32_t rsv_08[2]; //* 0x08-0x0C - Reserved

    volatile uint32_t addr_pcie_rd_lo; //* 0x10 - PCIe Read Low Address
    volatile uint32_t addr_pcie_rd_hi; //* 0x14 - PCIe Read High Address
    volatile uint32_t length_pcie_rd;  //* 0x18 - PCIe Read Length

    volatile uint32_t addr_pcie_wr_lo; //* 0x1C - PCIe Write Low Address
    volatile uint32_t addr_pcie_wr_hi; //* 0x20 - PCIe Write High Address
    volatile uint32_t length_pcie_wr;  //* 0x24 - PCIe Write Length
    volatile uint32_t rsv_28[2];       //* 0x28-0x2C - Reserved

    volatile uint32_t addr_lad_rd_lo; //* 0x30 - Logic Adder Read Low Address
    volatile uint32_t addr_lad_rd_hi; //* 0x34 - Logic Adder Read High Address
    volatile uint32_t addr_lad_wr_lo; //* 0x38 - Logic Adder Write Low Address
    volatile uint32_t addr_lad_wr_hi; //* 0x3C - Logic Adder Write High Address
    volatile uint32_t length_lad;     //* 0x40 - Logic Adder Length
} GowinBar2;
