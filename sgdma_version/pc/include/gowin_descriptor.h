#include <stdint.h>

#ifndef GOWIN_DESCRIPTOR_H
#define GOWIN_DESCRIPTOR_H

#define SET_FLAG_EOP (1 << 1)
#define SET_FLAG_STOP_EOP ((1 << 0) | (1 << 1))
#define SET_FLAG_STOP_EOP_COMP ((1 << 0) | (1 << 1) | (1 << 2))
#define SET_FLAG_NUM_DESC(num_desc) (((uint32_t)(num_desc) & 0x7F) << 8)
#define IS_COMPLETED (1 << 2)

typedef struct __attribute__((packed, aligned(32))) {
    //* 0x00 - Stop[0], Eop[1], Completed[2], AdjDescNum[14:8]
    volatile uint32_t flags;
    volatile uint32_t length; //* 0x04 - Data Length (bytes)

    volatile uint32_t addr_src_lo; //* 0x08 - Source Low Address
    volatile uint32_t addr_src_hi; //* 0x0C - Source High Address

    volatile uint32_t addr_dst_lo; //* 0x10 - Destination Low Address
    volatile uint32_t addr_dst_hi; //* 0x14 - Destination High Address

    volatile uint32_t next_lo; //* 0x18 - Next Descriptor Low Address
    volatile uint32_t next_hi; //* 0x1C - Next Descriptor High Address
} GowinDescriptor;

const size_t SIZE_DESC = sizeof(GowinDescriptor);

#endif // GOWIN_DESCRIPTOR_H
