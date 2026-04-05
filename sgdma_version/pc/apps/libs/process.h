#include <stdint.h>

#include "../../include/gowin_bar0.h"
#include "../../include/gowin_bar2.h"

#define BAR0_SIZE (1024 * 16)
#define BAR2_SIZE (1024 * 2)
#define DMA_SIZE (1024 * 16) //! 16 for pretty printing

typedef struct process {
    uint64_t dma_src;
    uint8_t *mem_src;

    uint64_t dma_dst;
    uint8_t *mem_dst;

    int fd;
    GowinBar0 *gwbar0;
    GowinBar2 *gwbar2;
} Process;

Process *init_proc();

void dest_proc(Process *proc);
