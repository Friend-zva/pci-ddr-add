#include <stdint.h>

#include "../../include/gowin_bar0.h"
#include "../../include/gowin_bar2.h"

typedef struct process {
    uint64_t desc_src;
    uint8_t *desc_src_m;

    uint64_t data_src;
    uint8_t *data_src_m;

    uint64_t desc_dst;
    uint8_t *desc_dst_m;

    uint64_t data_dst;
    uint8_t *data_dst_m;

    int fd;
    GowinBar0 *gwbar0;
    GowinBar2 *gwbar2;
} Process;

Process *init_proc(uint32_t size_data, uint32_t size_descs);

void dest_proc(Process *proc, uint32_t size_data, uint32_t size_descs);
