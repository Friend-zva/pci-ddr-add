#include <stdint.h>

#include "../../include/gowin_bar0.h"
#include "../../include/gowin_bar2.h"

typedef struct process {
    uint64_t desc_src;
    uint8_t *mdesc_src;

    uint64_t data_src;
    uint8_t *mdata_src;

    uint64_t desc_dst;
    uint8_t *mdesc_dst;

    uint64_t data_dst;
    uint8_t *mdata_dst;

    int fd;
    GowinBar0 *gwbar0;
    GowinBar2 *gwbar2;
} Process;

Process *init_proc(uint32_t size_data, uint32_t size_descs);

void dest_proc(Process *proc, uint32_t size_data, uint32_t size_descs);
