#include <stdio.h>

#include "dump.h"

static int DUMP_INFO = 1;

static const int SIZE_DUMP = 32;

void dump_source(uint64_t sa, volatile uint8_t *sp) {
    printf("0x%016lx : ", sa);
    for (int i = 0; i < SIZE_DUMP; i++) {
        uint16_t lo = *(uint16_t *)(&sp[i * 4]);
        uint16_t hi = *(uint16_t *)(&sp[i * 4 + 2]);
        printf("(0x%04x, 0x%04x) ", lo, hi);
    }
    printf("\n");
}

void dump_destination(uint64_t da, volatile uint8_t *dp) {
    printf("0x%016lx : ", da);
    for (int i = 0; i < SIZE_DUMP; i++) {
        uint32_t val = *(uint32_t *)(&dp[i * 4]);
        printf("0x%08x ", val);
    }
    printf("\n");
}
