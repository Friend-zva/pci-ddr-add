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
#include "../../include/gowin_bar2.h"
#include "../../include/gowin_descriptor.h"
#include "../../include/gowin_pcie_bar_drv_uapi.h"
#include "../libs/dump.h"
#include "../libs/gowin_utils.h"
#include "../libs/process.h"

#define MAXFF (0xFFFFFFFF)
#define TIMEOUT_POLL (100000000)

volatile sig_atomic_t flag_exit = 0;
void handle_sigint(int sig) { flag_exit = 1; }

int DBG_INFO = 1;
int DUMP_INFO = 1;

static void dump_sgdma_ch(const char *tag, volatile GowinDMAChannel *ch) {
    printf("%s ctrl=0x%08x desc_count=%u status0=0x%08x status1=0x%08x\n", tag,
           ch->ctrl, ch->desc_count, ch->status0, ch->status1);
    fflush(stdout);
}

int main(int argc, char *argv[]) {
    signal(SIGINT, handle_sigint);
    volatile int val;

    Process *proc = init_proc();
    if (proc == NULL) {
        return -1;
    }

    GowinBar0 *gwbar0 = (GowinBar0 *)proc->gwbar0;
    GowinBar2 *gwbar2 = (GowinBar2 *)proc->gwbar2;

    if (DBG_INFO) {
        val = gwbar0->rsv[0];
        printf("gwbar0 alive\n");
        fflush(stdout);
    }
    if (DBG_INFO) {
        val = gwbar2->rsv_28[0];
        printf("gwbar2 alive\n");
        fflush(stdout);
    }

    gwbar0->ctrl.ctrl_init = 1;
    while ((gwbar0->ctrl.stat_init & MAXFF) != PCIE_READY) {
        if (flag_exit) {
            dest_proc(proc);
            return -1;
        }
    }
    if (DBG_INFO) {
        printf("pcie ready\n");
        fflush(stdout);
    }

    struct gowin_ioctl_param param = {0};
    param.cfg_type = 2;
    param.cfg_where = 0x90; // Link Status
    val = ioctl(proc->fd, GOWIN_CONFIG_READ_DWORD, &param);
    if (val) {
        printf("Failed to check link status\n");
        dest_proc(proc);
        return -1;
    }

    param.cfg_type = 2;
    param.cfg_where = 0x88; // Device Status
    while (1) {
        if (!ioctl(proc->fd, GOWIN_CONFIG_READ_DWORD, &param) &&
            param.cfg_dword != 0xFFFFFFFF) {
            val = (param.cfg_dword & 0xFF1F) | (1 << 5);
            printf("payload: %i\n", val);
            break;
        }
    }

    uint32_t addr_ddr_h2c = 0x0000;
    uint32_t addr_ddr_c2h = 0x4000; // DMA_SIZE

    //? use payload here? current = 128.
    uint32_t cnt = 32; // 32 * 4 = 128B
    uint32_t length = cnt * 4;
    int size_data = DMA_SIZE / 2;
    int size_dump = 32;
    int num_descs = size_data / length;
    uint32_t block_size = (length + 127) & (~127);

    uint32_t size_descs =
        ((num_descs + 1) * sizeof(GowinDescriptor) + 32 + 127) & (~127);
    if (size_descs + size_data > DMA_SIZE) {
        printf("Failed to distributed dma area\n");
        dest_proc(proc);
        return -1;
    }

    volatile GowinDescriptor *descs_h2c = (volatile GowinDescriptor *)proc->mem_src;
    volatile uint32_t *poll_h2c =
        (volatile uint32_t *)(proc->mem_src + num_descs * sizeof(GowinDescriptor));

    volatile uint8_t *sp = proc->mem_src + size_descs;
    volatile uint64_t sa = proc->dma_src + size_descs;

    volatile GowinDescriptor *descs_c2h = (volatile GowinDescriptor *)proc->mem_dst;
    volatile uint32_t *poll_c2h =
        (volatile uint32_t *)(proc->mem_dst + num_descs * sizeof(GowinDescriptor));

    volatile uint8_t *dp = proc->mem_dst + size_descs;
    volatile uint64_t da = proc->dma_dst + size_descs;

    volatile uint64_t write_back =
        proc->dma_dst + num_descs * sizeof(GowinDescriptor) + 32;

    for (int i = 0; i < size_data; i++) {
        *(uint16_t *)(&sp[i * 2]) = i % 65536;
    }

    if (DUMP_INFO) {
        dump_source((uint8_t *)sp, size_dump);
    }
    if (DBG_INFO) {
        printf("*** Init: %i descriptors ***\n", num_descs);
    }

    // ====================
    // Host PC -> FPGA DDR3
    // ====================
    *poll_h2c = 0;

    for (int i = 0; i < num_descs; i++) {
        descs_h2c[i].length = length;
        descs_h2c[i].addr_src_lo = sa & MAXFF;
        descs_h2c[i].addr_src_hi = (sa >> 32) & MAXFF;
        // overhead
        descs_h2c[i].addr_dst_lo = 0;
        descs_h2c[i].addr_dst_hi = 0;

        if (i == num_descs - 1) {
            descs_h2c[i].flags = SET_FLAG_STOP_EOP;
            descs_h2c[i].next_lo = 0;
            descs_h2c[i].next_hi = 0;
        } else {
            descs_h2c[i].flags = SET_FLAG_EOP;
            uint64_t desc_next = proc->dma_src + (i + 1) * sizeof(GowinDescriptor);
            descs_h2c[i].next_lo = desc_next & MAXFF;
            descs_h2c[i].next_hi = (desc_next >> 32) & MAXFF;
        }
        sa += block_size;
    }

    gwbar0->h2c[0].addr_desc_lo = proc->dma_src & MAXFF;
    gwbar0->h2c[0].addr_desc_hi = (proc->dma_src >> 32) & MAXFF;
    gwbar0->h2c[0].addr_poll_lo =
        (proc->dma_src + num_descs * sizeof(GowinDescriptor)) & MAXFF;
    gwbar0->h2c[0].addr_poll_hi =
        ((proc->dma_src + num_descs * sizeof(GowinDescriptor)) >> 32) & MAXFF;
    gwbar0->h2c[0].num_desc_adj = num_descs - 1;

    gwbar2->addr_ddr_h2c = addr_ddr_h2c;
    gwbar2->leng_ddr_h2c = size_data;

    gwbar2->ctrl = BAR2_PCIE_WR_START;
    gwbar0->h2c[0].ctrl = SGDMA_POLL_START;

    if (DBG_INFO) {
        dump_sgdma_ch("h2c:start", &gwbar0->h2c[0]);
    }

    int timeout_h2c = TIMEOUT_POLL;
    volatile uint32_t prev_h2c_desc_count = gwbar0->h2c[0].desc_count;
    volatile uint32_t prev_h2c_status0 = gwbar0->h2c[0].status0;
    volatile uint32_t prev_h2c_status1 = gwbar0->h2c[0].status1;

    while (!(*poll_h2c) && !flag_exit && --timeout_h2c > 0) {
        if (descs_h2c[0].flags & IS_COMPLETED) {
            printf("h2c: completed\n");
            break;
        }

        if ((timeout_h2c & ((1u << 20) - 1)) == 0) {
            uint32_t dc = gwbar0->h2c[0].desc_count;
            uint32_t s0 = gwbar0->h2c[0].status0;
            uint32_t s1 = gwbar0->h2c[0].status1;
            if (dc != prev_h2c_desc_count || s0 != prev_h2c_status0 ||
                s1 != prev_h2c_status1) {
                dump_sgdma_ch("h2c:run ", &gwbar0->h2c[0]);
                prev_h2c_desc_count = dc;
                prev_h2c_status0 = s0;
                prev_h2c_status1 = s1;
            }
        }
    }
    if (timeout_h2c <= 0) {
        printf("h2c: timeout\n");
    }
    gwbar0->h2c[0].ctrl = SGDMA_STOP;

    if (DBG_INFO) {
        dump_sgdma_ch("h2c:stop ", &gwbar0->h2c[0]);
    }

    if (flag_exit) {
        dest_proc(proc);
        return 1;
    }

    // ==================================
    // Logic Adder: DDR3 -> Logic -> DDR3
    // ==================================
    gwbar2->addr_lad_rd = addr_ddr_h2c;
    gwbar2->addr_lad_wr = addr_ddr_c2h;
    gwbar2->leng_lad = size_data;

    gwbar2->ctrl = BAR2_LAD_START;

    int timeout_lad = TIMEOUT_POLL;
    while (!flag_exit && --timeout_lad > 0) {
        if (gwbar2->status & BAR2_LAD_DONE) {
            break;
        }
    }
    if (timeout_lad <= 0) {
        printf("lad: timeout\n");
    }
    gwbar2->ctrl = BAR2_LAD_STOP;

    // ====================
    // FPGA DDR3 -> Host PC
    // ====================
    *poll_c2h = 0;
    uint64_t current_sa_c2h = proc->dma_dst + size_descs;

    for (int i = 0; i < num_descs; i++) {
        descs_c2h[i].length = length;
        descs_c2h[i].addr_dst_lo = da & MAXFF;
        descs_c2h[i].addr_dst_hi = (da >> 32) & MAXFF;
        // write-back
        descs_c2h[i].addr_src_lo = write_back & MAXFF;
        descs_c2h[i].addr_src_hi = (write_back >> 32) & MAXFF;

        if (i == num_descs - 1) {
            descs_c2h[i].flags = SET_FLAG_STOP_EOP;
            descs_c2h[i].next_lo = 0;
            descs_c2h[i].next_hi = 0;
        } else {
            descs_c2h[i].flags = SET_FLAG_EOP;
            uint64_t desc_next = proc->dma_dst + (i + 1) * sizeof(GowinDescriptor);
            descs_c2h[i].next_lo = desc_next & MAXFF;
            descs_c2h[i].next_hi = (desc_next >> 32) & MAXFF;
        }
        da += block_size;
    }

    gwbar0->c2h[0].addr_desc_lo = proc->dma_dst & MAXFF;
    gwbar0->c2h[0].addr_desc_hi = (proc->dma_dst >> 32) & MAXFF;
    gwbar0->c2h[0].addr_poll_lo =
        (proc->dma_dst + num_descs * sizeof(GowinDescriptor)) & MAXFF;
    gwbar0->c2h[0].addr_poll_hi =
        ((proc->dma_dst + num_descs * sizeof(GowinDescriptor)) >> 32) & MAXFF;
    gwbar0->c2h[0].num_desc_adj = num_descs - 1;

    gwbar0->c2h[0].ctrl = SGDMA_POLL_START;

    gwbar2->addr_ddr_c2h = addr_ddr_c2h;
    gwbar2->leng_ddr_c2h = size_data;

    gwbar2->ctrl = BAR2_PCIE_RD_START;

    if (DBG_INFO) {
        dump_sgdma_ch("c2h:start", &gwbar0->c2h[0]);
    }

    int timeout_c2h = TIMEOUT_POLL;
    volatile uint32_t prev_c2h_desc_count = gwbar0->c2h[0].desc_count;
    volatile uint32_t prev_c2h_status0 = gwbar0->c2h[0].status0;
    volatile uint32_t prev_c2h_status1 = gwbar0->c2h[0].status1;

    while (!(*poll_c2h) && !flag_exit && --timeout_c2h > 0) {
        if (descs_c2h[0].flags & IS_COMPLETED) {
            printf("c2h: completed\n");
            break;
        }

        if ((timeout_c2h & ((1u << 20) - 1)) == 0) {
            uint32_t dc = gwbar0->c2h[0].desc_count;
            uint32_t s0 = gwbar0->c2h[0].status0;
            uint32_t s1 = gwbar0->c2h[0].status1;
            if (dc != prev_c2h_desc_count || s0 != prev_c2h_status0 ||
                s1 != prev_c2h_status1) {
                dump_sgdma_ch("c2h:run ", &gwbar0->c2h[0]);
                prev_c2h_desc_count = dc;
                prev_c2h_status0 = s0;
                prev_c2h_status1 = s1;
            }
        }
    }
    if (timeout_c2h <= 0) {
        printf("c2h: timeout\n");
    }
    gwbar0->c2h[0].ctrl = SGDMA_STOP;

    if (DBG_INFO) {
        dump_sgdma_ch("c2h:stop ", &gwbar0->c2h[0]);
    }

    if (flag_exit) {
        dest_proc(proc);
        return 1;
    }

    if (DUMP_INFO) {
        dump_destination((uint8_t *)dp, size_dump);
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
    gwbar2->ctrl = BAR2_LAD_STOP;

    dest_proc(proc);
    if (flag_exit) {
        return 1;
    }

    return 0;
}
