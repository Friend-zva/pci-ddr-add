#include <stdlib.h>
#include <string.h>

#include "config.h"

static const int SIZE_BLOCK_MIN = 128;
static const int SIZE_DATA_MAX = 4194304; // 4 MB

Config init_config(int argc, char *argv[]) {
    int size_data = 2048;
    int size_block = SIZE_BLOCK_MIN;
    int en_dumping = 0;

    if (argc > 1) {
        size_data = strtol(argv[1], NULL, 0);
        if (size_data < SIZE_BLOCK_MIN) {
            size_data = SIZE_BLOCK_MIN;
        } else {
            size_data = ROUND2_TO(size_data, 32);
        }

        if (size_data > SIZE_DATA_MAX) {
            size_data = SIZE_DATA_MAX;
        }
    }
    if (argc > 2) {
        size_block = strtol(argv[2], NULL, 0);
        if (size_block < SIZE_BLOCK_MIN) {
            size_block = SIZE_BLOCK_MIN;
        } else {
            size_block = ROUND2_TO(size_block, 32);
        }

        if (size_block > size_data) {
            size_block = size_data;
        }
    }
    if (argc > 3) {
        if (!strcmp(argv[3], "y") || !strcmp(argv[3], "1")) {
            en_dumping = 1;
        }
    }

    return (Config){.size_data = (uint32_t)size_data,
                    .size_block = (uint32_t)size_block,
                    .en_dumping = en_dumping};
}
