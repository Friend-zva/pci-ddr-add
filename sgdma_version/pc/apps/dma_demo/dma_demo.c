#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <arpa/inet.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/mman.h>

#include "../../include/gowin_bar0.h"
#include "../../include/gowin_descriptor.h"
#include "../../include/gowin_pcie_bar_drv_uapi.h"
#include "../libs/dump.h"
#include "../libs/gowin_utils.h"
#include "../libs/process.h"

#define MAXFF 0xFFFFFFFF

volatile sig_atomic_t flag_exit = 0;
void handle_sigint(int sig) { flag_exit = 1; }

int DBG_INFO = 1;
int DUMP_INFO = 1;

int main(int argc, char *argv[]) {
    signal(SIGINT, handle_sigint);
    volatile int val;

    Process *proc = init_proc();
    if (proc == NULL) {
        return -1;
    }

    GowinBar0 *gwbar0 = (GowinBar0 *)proc->gwbar0;

    gwbar0->ctrl.ctrl_init = 1;
    while ((gwbar0->ctrl.ctrl_init & MAXFF) != 0xaa009719) {
        if (flag_exit) {
            break;
        }
    }

    struct gowin_ioctl_param param = {0};
    param.cfg_type = 2;
    param.cfg_where = 0x90;
    val = ioctl(proc->fd, GOWIN_CONFIG_READ_DWORD, &param);
    if (val) {
        dest_proc(proc);
        return -1;
    }

    param.cfg_type = 2;
    param.cfg_where = 0x88;
    while (1) {
        if (!ioctl(proc->fd, GOWIN_CONFIG_READ_DWORD, &param) &&
            param.cfg_dword != MAXFF) {
            val = (param.cfg_dword & 0xFF1F) | (1 << 5); //? payload 256B?
            break;
        }
    }

    //? volatile? for bar too?
    volatile GowinDescriptor *desc_h2c = (volatile GowinDescriptor *)proc->mem_src;
    volatile uint32_t *poll_h2c = (volatile uint32_t *)(proc->mem_src + 32);

    volatile uint8_t *sp = proc->mem_src + 64;
    volatile uint64_t sa = proc->dma_src + 64;

    volatile GowinDescriptor *desc_c2h = (volatile GowinDescriptor *)proc->mem_dst;
    volatile uint32_t *poll_c2h = (volatile uint32_t *)(proc->mem_dst + 32);

    volatile uint8_t *dp = proc->mem_dst + 64;
    volatile uint64_t da = proc->dma_dst + 64;

    uint32_t cnt = 128; // 128 * 4 = 512B
    uint32_t length = cnt * 4;
    int size = DMA_SIZE / 2;
    int size_dump = 32;
    int loop = size / length;
    uint32_t block_size = (length + 511) & (~511);

    for (int i = 0; i < size; i++) {
        *(uint16_t *)(&sp[i * 2]) = i % 65536;
    }

    int h2c_count = 0, c2h_count = 0;
    while (h2c_count < loop || c2h_count < loop) {
        if (DUMP_INFO) {
            dump_source((uint8_t *)sp, size_dump);
        }
        if (DBG_INFO) {
            printf("*** Loop ***\nh2c_count: %i, c2h_count: %i\n", h2c_count,
                   c2h_count);
        }

        if (h2c_count < loop) {
            *poll_h2c = 0;

            desc_h2c->flags = SET_FLAG;
            desc_h2c->length = cnt;
            desc_h2c->addr_src_lo = sa & MAXFF;
            desc_h2c->addr_src_hi = (sa >> 32) & MAXFF;
            // overhead data
            desc_h2c->addr_dst_lo = 0;
            desc_h2c->addr_dst_hi = 0;

            gwbar0->h2c[0].addr_desc_lo = proc->dma_src & MAXFF;
            gwbar0->h2c[0].addr_desc_hi = (proc->dma_src >> 32) & MAXFF;
            gwbar0->h2c[0].addr_poll_lo = (proc->dma_src + 32) & MAXFF;
            gwbar0->h2c[0].addr_poll_hi = ((proc->dma_src + 32) >> 32) & MAXFF;
            gwbar0->h2c[0].num_desc_adj = 0;

            gwbar0->h2c[0].ctrl = SGDMA_POLL_START;
        }

        if (c2h_count < loop) {
            *poll_c2h = 0;

            desc_c2h->flags = SET_FLAG;
            desc_c2h->length = cnt;
            desc_c2h->addr_dst_lo = da & MAXFF;
            desc_c2h->addr_dst_hi = (da >> 32) & MAXFF;
            // write-back
            desc_c2h->addr_src_lo = (proc->dma_dst + 36) & MAXFF;
            desc_c2h->addr_src_hi = ((proc->dma_dst + 36) >> 32) & MAXFF;

            gwbar0->c2h[0].addr_desc_lo = proc->dma_dst & MAXFF;
            gwbar0->c2h[0].addr_desc_hi = (proc->dma_dst >> 32) & MAXFF;
            gwbar0->c2h[0].addr_poll_lo = (proc->dma_dst + 32) & MAXFF;
            gwbar0->c2h[0].addr_poll_hi = ((proc->dma_dst + 32) >> 32) & MAXFF;
            gwbar0->c2h[0].num_desc_adj = 0;

            gwbar0->c2h[0].ctrl = SGDMA_POLL_START;
        }

        while (!flag_exit) {
            int h2c_done = (h2c_count >= loop) || (*poll_h2c > 0);
            int c2h_done = (c2h_count >= loop) || (*poll_c2h > 0);

            if (h2c_done && c2h_done) {
                break;
            }
        }
        if (flag_exit) {
            break;
        }

        if (h2c_count < loop) {
            gwbar0->h2c[0].ctrl = SGDMA_STOP;
            sa += block_size;
            sp += block_size;
            if (sa + block_size > proc->dma_src + DMA_SIZE) {
                sa = proc->dma_src + 64;
                sp = proc->mem_src + 64;
            }
            h2c_count++;
        }

        if (c2h_count < loop) {
            gwbar0->c2h[0].ctrl = SGDMA_STOP;
            da += block_size;
            dp += block_size;
            if (da + block_size > proc->dma_dst + DMA_SIZE) {
                da = proc->dma_dst + 64;
                dp = proc->mem_dst + 64;
            }
            c2h_count++;
        }

        if (DUMP_INFO) {
            dump_destination((uint8_t *)dp, size_dump);
        }
    }

    for (int i = 0; i < size_dump; i++) {
        uint32_t d = ((uint32_t *)dp)[i];
        uint32_t s = ((uint16_t *)sp)[i * 2] + ((uint16_t *)sp)[i * 2 + 1];
        if (d != s) {
            printf("*** FAILED ***\n");
            break;
        }
    }

    gwbar0->h2c[0].ctrl = SGDMA_STOP;
    gwbar0->c2h[0].ctrl = SGDMA_STOP;
    dest_proc(proc);
    if (flag_exit) {
        return 1;
    }

    return 0;
}
