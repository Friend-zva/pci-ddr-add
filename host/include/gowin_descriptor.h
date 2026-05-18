#include <stdint.h>

#ifndef GOWIN_DESCRIPTOR_H
#define GOWIN_DESCRIPTOR_H

#define SET_FLAG_STOP (1 << 0)
#define SET_FLAG_EOP (1 << 1)
#define SET_FLAG_COMP (1 << 2)
#define SET_FLAG_NUM_DESC(num_desc) (((uint32_t)(num_desc) & 0x7F) << 8)

#define IS_DESC_COMPLETED (1 << 4)
#define IS_LAST_DESC(i) (((uint32_t)i & 0x7F) == 0x7F)

#define MAX_DESC_IN_BLOCK 127
#define DESC_MODULE(num_desc)                                                       \
    ((num_desc) > MAX_DESC_IN_BLOCK ? MAX_DESC_IN_BLOCK : (num_desc))

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

#define SIZE_DESC sizeof(GowinDescriptor)

#endif // GOWIN_DESCRIPTOR_H
