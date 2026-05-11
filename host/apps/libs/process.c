#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/mman.h>

#include "gowin_utils.h"
#include "process.h"

Process *init_proc(uint32_t size_data, uint32_t size_descs) {
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

    proc->desc_src = request_mem(fd, 0, size_descs);
    if (proc->desc_src == 0) {
        return NULL;
    }
    proc->desc_src_m = mmap_mem(fd, 0, size_descs);
    if (proc->desc_src_m == NULL) {
        return NULL;
    }
    proc->data_src = request_mem(fd, 1, size_data);
    if (proc->data_src == 0) {
        return NULL;
    }
    proc->data_src_m = mmap_mem(fd, 1, size_data);
    if (proc->data_src_m == NULL) {
        return NULL;
    }

    proc->desc_dst = request_mem(fd, 2, size_descs);
    if (proc->desc_dst == 0) {
        return NULL;
    }
    proc->desc_dst_m = mmap_mem(fd, 2, size_descs);
    if (proc->desc_dst_m == NULL) {
        return NULL;
    }
    proc->data_dst = request_mem(fd, 3, size_data);
    if (proc->data_dst == 0) {
        return NULL;
    }
    proc->data_dst_m = mmap_mem(fd, 3, size_data);
    if (proc->data_dst_m == NULL) {
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

void dest_proc(Process *proc, uint32_t size_data, uint32_t size_descs) {
    if (proc == NULL) {
        return;
    }

    proc->gwbar0->h2c[0].ctrl = SGDMA_STOP;
    proc->gwbar0->c2h[0].ctrl = SGDMA_STOP;
    if (proc->gwbar0) {
        munmap(proc->gwbar0, BAR0_SIZE);
    }
    proc->gwbar2->ctrl = BAR2_PCIE_WR_STOP | BAR2_PCIE_RD_STOP | BAR2_LAD_STOP;
    if (proc->gwbar2) {
        munmap(proc->gwbar2, BAR2_SIZE);
    }

    if (proc->data_dst_m) {
        munmap(proc->data_dst_m, size_data);
    }
    if (proc->data_dst) {
        release_mem(proc->fd, 3);
    }
    if (proc->desc_dst_m) {
        munmap(proc->desc_dst_m, size_descs);
    }
    if (proc->desc_dst) {
        release_mem(proc->fd, 2);
    }

    if (proc->data_src_m) {
        munmap(proc->data_src_m, size_data);
    }
    if (proc->data_src) {
        release_mem(proc->fd, 1);
    }
    if (proc->desc_src_m) {
        munmap(proc->desc_src_m, size_descs);
    }
    if (proc->desc_src) {
        release_mem(proc->fd, 0);
    }

    dev_close(proc->fd);
    free(proc);
}
