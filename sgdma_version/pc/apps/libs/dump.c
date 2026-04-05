#include <stdio.h>

#include "dump.h"

void dump_source(volatile uint8_t *sp, int size_dump) {
    for (int i = 0; i < size_dump; i++) {
        uint16_t lo = *(uint16_t *)(&sp[i * 4]);
        uint16_t hi = *(uint16_t *)(&sp[i * 4 + 2]);
        printf("(0x%04x, 0x%04x) ", lo, hi);
    }
    printf("\n");
}

void dump_destination(volatile uint8_t *dp, int size_dump) {
    for (int i = 0; i < size_dump; i++) {
        uint32_t val = *(uint32_t *)(&dp[i * 4]);
        printf("0x%08x ", val);
    }
    printf("\n");
}
