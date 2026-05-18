#include <stdint.h>

#define ROUND2_TO(num, base) (((num) + (base - 1)) & ~(base - 1))

typedef struct {
    uint32_t size_data;
    uint32_t size_block;
    int en_dumping;
} Config;

Config init_config(int argc, char *argv[]);
