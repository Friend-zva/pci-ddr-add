#include <stdint.h>

#define SET_FLAG                                                                    \
    ((1 << 0) | (1 << 1) | (1 << 2)) // Stop=1, Eop=1, Completed=1, Adj=0

typedef struct {
    //* 0x00 - Stop[0], Eop[1], Completed[2], AdjDescNum[14:8]
    volatile uint32_t flags;
    volatile uint32_t length;      //* 0x04 - Data length in bytes
    volatile uint32_t addr_src_lo; //* 0x08 - Source Low Address
    volatile uint32_t addr_src_hi; //* 0x0C - Source High Address
    volatile uint32_t addr_dst_lo; //* 0x10 - Destination Low Address
    volatile uint32_t addr_dst_hi; //* 0x14 - Destination High Address
    volatile uint32_t next_lo;     //* 0x18 - Next Descriptor Low Address
    volatile uint32_t next_hi;     //* 0x1C - Next Descriptor High Address
} GowinDescriptor;
