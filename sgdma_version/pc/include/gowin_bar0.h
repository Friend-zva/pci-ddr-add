#include <stdint.h>

// For control register (0x04/0x08)
#define SGDMA_POLL_START 0x0003 // Bit:0 = 1 (Start), Bit:1 = 1 (Poll mode)
#define SGDMA_STOP 0x0000

typedef struct {
    volatile uint32_t id;           //* 0x00 - Channel Identifier (RO)
    volatile uint32_t ctrl;         //* 0x04 - Channel Control (RW)
    volatile uint32_t ctrl_w1s;     //* 0x08 - Channel Control (W1S)
    volatile uint32_t ctrl_w1c;     //* 0x0C - Channel Control (W1C)
    volatile uint32_t addr_desc_lo; //* 0x10 - Descriptor Low Address (RW)
    volatile uint32_t addr_desc_hi; //* 0x14 - Descriptor High Address (RW)
    volatile uint32_t addr_poll_lo; //* 0x18 - Poll Low Address (RW)
    volatile uint32_t addr_poll_hi; //* 0x1C - Poll High Address (RW)
    volatile uint32_t desc_count;   //* 0x20 - Completed Descriptor Count (RO)
    volatile uint32_t rsv_24;       //* 0x24 - Reserved
    volatile uint32_t num_desc_adj; //* 0x28 - Descriptor Adjacent Number (RW)
    volatile uint32_t rsv_2c;       //* 0x2C - Reserved
    volatile uint32_t status0;      //* 0x30 - Status (RW1C/RO)
    volatile uint32_t status1;      //* 0x34 - Status (RC)
    volatile uint32_t rsv_38[5];    //* 0x38-0x4B - Reserved
    volatile uint32_t credit;       //* 0x4C - Credit (RW, C2H only)
    volatile uint32_t rsv_50[44];   //* 0x50-0xFF - Reserved
} GowinDMAChannel;

typedef struct {
    volatile uint32_t id;         //* 0x00 - Control Identifier (RO)
    volatile uint32_t ctrl_init;  //* 0x04 - Initial Control (WO)
    volatile uint32_t stat_init;  //* 0x08 - Initial Status (RO)
    volatile uint32_t rsv_0c[61]; //* 0x0C-0xFF - Reserved
} GowinControl;

typedef struct {
    GowinDMAChannel h2c[16];              //* 0x0000 - 0x0FFF (1 channel only)
    GowinDMAChannel c2h[16];              //* 0x1000 - 0x1FFF (1 channel only)
    volatile uint32_t rsv_ctrl_pre[64];   //* 0x2000 - 0x20FF (skip ID:0000)
    GowinControl ctrl;                    //* 0x2100 - 0x21FF (ID:0001)
    volatile uint32_t rsv_ctrl_post[896]; //* 0x2200 - 0x2FFF (skip ID:0010-1111)
    volatile uint32_t rsv[1024];          //* 0x3000 - 0x3FFF
} GowinBar0;
