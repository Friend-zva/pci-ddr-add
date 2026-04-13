#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/mman.h>

#include "gowin_utils.h"
#include "process.h"

Process *init_proc() {
    int fd = dev_open(NULL);
    if (fd < 0) {
        fprintf(stderr, "Failed to open the device (%s)\n", strerror(errno));
        return NULL;
    }

    Process *proc = (Process *)malloc(sizeof(Process));
    if (proc == NULL) {
        fprintf(stderr, "Failed to allocate memory\n");
        return NULL;
    }

    proc->dma_src = request_mem(fd, 0, DMA_SIZE);
    if (proc->dma_src == 0) {
        return NULL;
    }
    proc->mem_src = mmap_mem(fd, 0, DMA_SIZE);
    if (proc->mem_src == NULL) {
        return NULL;
    }
    proc->dma_dst = request_mem(fd, 1, DMA_SIZE);
    if (proc->dma_dst == 0) {
        return NULL;
    }
    proc->mem_dst = mmap_mem(fd, 1, DMA_SIZE);
    if (proc->mem_dst == NULL) {
        return NULL;
    }

    proc->fd = fd;

    uint64_t *bar0 = mmap_bar(fd, 0, BAR0_SIZE);
    if (bar0 == NULL) {
        return NULL;
    }
    proc->gwbar0 = (GowinBar0 *)bar0;
    uint64_t *bar2 = mmap_bar(fd, 2, BAR2_SIZE);
    if (bar2 == NULL) {
        return NULL;
    }
    proc->gwbar2 = (GowinBar2 *)bar2;

    printf("init_proc() passed\n");
    fflush(stdout);

    return proc;
}

void dest_proc(Process *proc) {
    if (proc == NULL) {
        return;
    }
    if (proc->gwbar0) {
        munmap(proc->gwbar0, BAR0_SIZE);
    }
    if (proc->gwbar2) {
        munmap(proc->gwbar2, BAR2_SIZE);
    }
    if (proc->mem_dst) {
        munmap(proc->mem_dst, DMA_SIZE);
    }
    if (proc->dma_dst) {
        release_mem(proc->fd, 1);
    }
    if (proc->mem_src) {
        munmap(proc->mem_src, DMA_SIZE);
    }
    if (proc->dma_src) {
        release_mem(proc->fd, 0);
    }
    dev_close(proc->fd);
    free(proc);
}
