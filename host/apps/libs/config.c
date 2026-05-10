#include <stdlib.h>
#include <string.h>

#include "config.h"

Config init_config(int argc, char *argv[]) {
    int size_data = 4096;
    int size_block = 128;
    int en_dumping = 0;

    if (argc > 1) {
        size_data = strtol(argv[2], NULL, 0);
        if (size_data <= 0) {
            size_data = 4096;
        }
        size_data = (size_data + 1023) & (~1023);
    }
    if (argc > 2) {
        size_block = strtol(argv[1], NULL, 0);
        if (size_block <= 0) {
            size_block = 128;
        }
        size_block = (size_block + 31) & (~31);
    }
    if (argc > 3) {
        if (!strcmp(argv[3], "y") || !strcmp(argv[3], "1")) {
            en_dumping = 1;
        }
    }

    return (Config){.size_block = (uint32_t)size_block,
                    .size_data = (uint32_t)size_data,
                    .en_dumping = en_dumping};
}
