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

#define PP_ADDR_LO(addr) ((addr) & 0xFFFFFFFF)
#define PP_ADDR_HI(addr) ((addr >> 32) & 0xFFFFFFFF)

static const int TIMEOUT_POLL = 1000000;

static volatile sig_atomic_t flag_exit = 0;
void handle_sigint(int sig) { flag_exit = 1; }

static int DBG_INFO = 1;
static int DUMP_INFO = 1;
static int FILL_INFO = 0;
static int FILL_FLAG_ALL = 0;
static int FILL_FLAG_LAST = 1;

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
    while (gwbar0->ctrl.stat_init != PCIE_READY) {
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

    uint32_t addr_ddr_h2c = 0x1000;
    uint32_t addr_ddr_c2h = 0x2000 + DMA_SIZE;

    uint32_t cnt_dword = 256;
    uint32_t length = cnt_dword * 4;

    int size_data = DMA_SIZE / 2;
    int num_descs = size_data / length;
    int num_desc_adj = num_descs - 1;

    uint32_t offset_safe = 32;
    uint32_t offset_poll = num_descs * SIZE_DESC + offset_safe;
    uint32_t offset_oh_wb = offset_poll + offset_safe;
    uint32_t offset_data = offset_oh_wb + 2 * offset_safe;
    if (offset_data + size_data > DMA_SIZE) {
        printf("Failed to distributed dma area\n");
        dest_proc(proc);
        return -1;
    }

    // h2c

    volatile GowinDescriptor *desc_h2c_p = (GowinDescriptor *)proc->mem_src;
    uint64_t desc_h2c_a = proc->dma_src;

    volatile uint32_t *poll_h2c_p = (uint32_t *)(proc->mem_src + offset_poll);
    *poll_h2c_p = 0;
    uint64_t poll_h2c_a = proc->dma_src + offset_poll;

    volatile uint32_t *overhead_p = (uint32_t *)(proc->mem_src + offset_oh_wb);
    uint64_t overhead_a = proc->dma_src + offset_oh_wb;

    volatile uint8_t *sp = proc->mem_src + offset_data;
    uint64_t sa = proc->dma_src + offset_data;

    for (int i = 0; i < size_data / 2; i++) {
        *(uint16_t *)(&sp[i * 2]) = i % 65536;
    }

    if (DUMP_INFO) {
        dump_source(sp);
    }

    // c2h

    volatile GowinDescriptor *desc_c2h_p = (GowinDescriptor *)proc->mem_dst;
    uint64_t desc_c2h_a = proc->dma_dst;

    volatile uint32_t *poll_c2h_p = (uint32_t *)(proc->mem_dst + offset_poll);
    *poll_c2h_p = 0;
    uint64_t poll_c2h_a = proc->dma_dst + offset_poll;

    volatile uint32_t *write_back_p = (uint32_t *)(proc->mem_dst + offset_oh_wb);
    uint64_t write_back_a = proc->dma_dst + offset_oh_wb;

    volatile uint8_t *dp = proc->mem_dst + offset_data;
    uint64_t da = proc->dma_dst + offset_data;

    if (DBG_INFO) {
        printf("*** Init: %i descriptors ***\n", num_descs);
    }

    if (DBG_INFO) {
        printf("Status0: 0x%08x 0x%08x 0x%08x 0x%08x 0x%08x 0x%08x\n", *poll_h2c_p,
               gwbar0->h2c[0].ctrl, gwbar0->h2c[0].status0,
               gwbar0->h2c[0].desc_count, desc_h2c_p[0].flags,
               desc_h2c_p[num_desc_adj].flags);
        fflush(stdout);
    }

    // ====================
    // Host PC -> FPGA DDR3
    // ====================
    for (int i = 0; i < num_desc_adj; i++) {
        desc_h2c_p->flags =
            FILL_FLAG_ALL ? SET_FLAG_NUM_DESC(num_desc_adj - i) : 0x0;
        desc_h2c_p->length = length;
        desc_h2c_p->addr_src_lo = PP_ADDR_LO(sa);
        desc_h2c_p->addr_src_hi = PP_ADDR_HI(sa);
        desc_h2c_p->addr_dst_lo = 0x0;
        desc_h2c_p->addr_dst_hi = 0x0;

        uint64_t desc_next_a = proc->dma_src + (i + 1) * SIZE_DESC;
        desc_h2c_p->next_lo = FILL_INFO ? PP_ADDR_LO(desc_next_a) : 0x0;
        desc_h2c_p->next_hi = FILL_INFO ? PP_ADDR_HI(desc_next_a) : 0x0;

        desc_h2c_p += 1;
        sa += length;
    }

    desc_h2c_p->flags = FILL_FLAG_LAST ? SET_FLAG_STOP_EOP_COMP : SET_FLAG_STOP;
    desc_h2c_p->length = length;
    desc_h2c_p->addr_src_lo = PP_ADDR_LO(sa);
    desc_h2c_p->addr_src_hi = PP_ADDR_HI(sa);
    desc_h2c_p->addr_dst_lo = FILL_INFO ? PP_ADDR_LO(overhead_a) : 0x0;
    desc_h2c_p->addr_dst_hi = FILL_INFO ? PP_ADDR_HI(overhead_a) : 0x0;
    desc_h2c_p->next_lo = 0x0;
    desc_h2c_p->next_hi = 0x0;

    gwbar0->h2c[0].addr_desc_lo = PP_ADDR_LO(desc_h2c_a);
    gwbar0->h2c[0].addr_desc_hi = PP_ADDR_HI(desc_h2c_a);
    gwbar0->h2c[0].addr_poll_lo = PP_ADDR_LO(poll_h2c_a);
    gwbar0->h2c[0].addr_poll_hi = PP_ADDR_HI(poll_h2c_a);
    gwbar0->h2c[0].num_desc_adj = num_desc_adj;

    gwbar2->addr_ddr_h2c = PP_ADDR_LO(addr_ddr_h2c);
    gwbar2->leng_ddr_h2c = size_data;

    gwbar2->ctrl = BAR2_PCIE_WR_START;
    gwbar0->h2c[0].ctrl = SGDMA_START_POLL;

    int timeout_h2c = TIMEOUT_POLL;
    while (!(*poll_h2c_p) && --timeout_h2c > 0 && !flag_exit) {
        if (DBG_INFO) {
            printf("Status: 0x%08x 0x%08x 0x%08x 0x%08x 0x%08x 0x%08x\n",
                   *poll_h2c_p, gwbar0->h2c[0].ctrl, gwbar0->h2c[0].status0,
                   gwbar0->h2c[0].desc_count, (desc_h2c_p - num_desc_adj)->flags,
                   desc_h2c_p->flags);
            fflush(stdout);
        }
        if (gwbar0->h2c[0].desc_count == num_descs) {
            printf("h2c: count\n");
            break;
        }
        if ((desc_c2h_p - num_desc_adj)->flags & DESC_COMPLETED) {
            printf("h2c: completed\n");
            break;
        }
        usleep(1);
    }
    if (timeout_h2c <= 0) {
        printf("h2c: timeout\n");
    }

    gwbar0->h2c[0].ctrl = SGDMA_STOP;
    gwbar2->ctrl = BAR2_PCIE_WR_STOP;

    if (flag_exit) {
        dest_proc(proc);
        return 1;
    }

    // ============================
    // Logic: DDR3 -> Adder -> DDR3
    // ============================
    gwbar2->addr_lad_rd = PP_ADDR_LO(addr_ddr_h2c);
    gwbar2->addr_lad_wr = PP_ADDR_LO(addr_ddr_c2h);
    gwbar2->leng_lad = size_data;

    gwbar2->ctrl = BAR2_LAD_START;

    int timeout_lad = TIMEOUT_POLL;
    while (!(gwbar2->status & BAR2_LAD_DONE) && --timeout_lad > 0 && !flag_exit) {
        usleep(1);
    }
    if (timeout_lad <= 0) {
        printf("lad: timeout\n");
    }

    gwbar2->ctrl = BAR2_LAD_STOP;

    if (flag_exit) {
        dest_proc(proc);
        return 1;
    }

    // ====================
    // FPGA DDR3 -> Host PC
    // ====================
    for (int i = 0; i < num_desc_adj; i++) {
        desc_c2h_p->flags =
            FILL_FLAG_ALL ? SET_FLAG_NUM_DESC(num_desc_adj - i) : 0x0;
        desc_c2h_p->length = length;
        desc_c2h_p->addr_src_lo = 0x0;
        desc_c2h_p->addr_src_hi = 0x0;
        desc_c2h_p->addr_dst_lo = PP_ADDR_LO(da);
        desc_c2h_p->addr_dst_hi = PP_ADDR_HI(da);

        uint64_t desc_next_a = proc->dma_dst + (i + 1) * SIZE_DESC;
        desc_c2h_p->next_lo = FILL_INFO ? PP_ADDR_LO(desc_next_a) : 0x0;
        desc_c2h_p->next_hi = FILL_INFO ? PP_ADDR_HI(desc_next_a) : 0x0;

        desc_c2h_p += 1;
        da += length;
    }

    desc_c2h_p->flags = FILL_FLAG_LAST ? SET_FLAG_STOP_EOP_COMP : SET_FLAG_STOP;
    desc_c2h_p->length = length;
    desc_c2h_p->addr_src_lo = PP_ADDR_LO(write_back_a);
    desc_c2h_p->addr_src_hi = PP_ADDR_HI(write_back_a);
    desc_c2h_p->addr_dst_lo = PP_ADDR_LO(da);
    desc_c2h_p->addr_dst_hi = PP_ADDR_HI(da);
    desc_c2h_p->next_lo = 0x0;
    desc_c2h_p->next_hi = 0x0;

    gwbar0->c2h[0].addr_desc_lo = PP_ADDR_LO(desc_c2h_a);
    gwbar0->c2h[0].addr_desc_hi = PP_ADDR_HI(desc_c2h_a);
    gwbar0->c2h[0].addr_poll_lo = PP_ADDR_LO(poll_c2h_a);
    gwbar0->c2h[0].addr_poll_hi = PP_ADDR_HI(poll_c2h_a);
    gwbar0->c2h[0].num_desc_adj = num_desc_adj;

    gwbar2->addr_ddr_c2h = PP_ADDR_LO(addr_ddr_c2h);
    gwbar2->leng_ddr_c2h = size_data;

    gwbar2->ctrl = BAR2_PCIE_RD_START;
    gwbar0->c2h[0].ctrl = SGDMA_START_POLL;

    int timeout_c2h = TIMEOUT_POLL;
    while (!(*poll_c2h_p) && --timeout_c2h > 0 && !flag_exit) {
        if (DBG_INFO) {
            printf("Status: 0x%08x 0x%08x 0x%08x 0x%08x 0x%08x 0x%08x\n",
                   *poll_c2h_p, gwbar0->c2h[0].ctrl, gwbar0->c2h[0].status0,
                   gwbar0->c2h[0].desc_count, (desc_c2h_p - num_desc_adj)->flags,
                   desc_c2h_p->flags);
            usleep(1);
        }
        if (gwbar0->c2h[0].desc_count == num_descs) {
            printf("c2h: count\n");
            break;
        }
        if ((desc_c2h_p - num_desc_adj)->flags & DESC_COMPLETED) {
            printf("c2h: completed\n");
            break;
        }
    }
    if (timeout_c2h <= 0) {
        printf("c2h: timeout\n");
    }

    gwbar0->c2h[0].ctrl = SGDMA_STOP;
    gwbar2->ctrl = BAR2_PCIE_RD_STOP;

    if (flag_exit) {
        dest_proc(proc);
        return 1;
    }

    for (int i = 0; i < size_data / 2; i++) {
        uint32_t d = ((uint32_t *)dp)[i];
        uint32_t s = ((uint16_t *)sp)[i * 2] + ((uint16_t *)sp)[i * 2 + 1];
        if (d != s) {
            printf("*** FAILED ***\n");
            break;
        }
    }

    if (DUMP_INFO) {
        dump_destination(dp);
    }

    dest_proc(proc);
    if (flag_exit) {
        return 1;
    }

    return 0;
}
