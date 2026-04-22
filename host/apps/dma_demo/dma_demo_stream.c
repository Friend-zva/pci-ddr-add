// =====================================
// Without Logic Adder (Simple Loopback)
// =====================================

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

#define PP_ADDR_LO(addr) ((addr) & 0xFFFFFFFF)
#define PP_ADDR_HI(addr) ((addr >> 32) & 0xFFFFFFFF)

static const int TIMEOUT_POLL = 1000000;

static volatile sig_atomic_t flag_exit = 0;
void handle_sigint(int sig) { flag_exit = 1; }

static int DBG_INFO = 1;
static int DUMP_INFO = 1;
static int FILL_INFO_ALL = 1;
static int FILL_INFO_LAST = 1;

int main(int argc, char *argv[]) {
    signal(SIGINT, handle_sigint);
    volatile int val;

    Process *proc = init_proc();
    if (proc == NULL) {
        return -1;
    }

    GowinBar0 *gwbar0 = (GowinBar0 *)proc->gwbar0;
    if (DBG_INFO) {
        val = gwbar0->rsv[0];
        printf("gwbar0 alive\n");
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

    uint32_t cnt_dword = 128;
    uint32_t length = cnt_dword * 4;

    int size_data = length; //?  DMA_SIZE / 2
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
    memset((void *)desc_h2c_p, 0, offset_poll);
    uint64_t desc_h2c_a = proc->dma_src;

    volatile uint32_t *poll_h2c_p = (uint32_t *)(proc->mem_src + offset_poll);
    *poll_h2c_p = 0;
    uint64_t poll_h2c_a = proc->dma_src + offset_poll;

    volatile uint32_t *overhead_p = (uint32_t *)(proc->mem_src + offset_oh_wb);
    *overhead_p = 0x01234567;
    uint64_t overhead_a = proc->dma_src + offset_oh_wb;

    volatile uint8_t *sp = proc->mem_src + offset_data;
    uint64_t sa = proc->dma_src + offset_data;

    for (int i = 0; i < size_data / 2; i++) {
        *(uint16_t *)(&sp[i * 2]) = i % 65536;
    }

    if (DUMP_INFO) {
        dump_source(sp);
    }

    desc_h2c_p->flags = SET_FLAG_STOP | SET_FLAG_EOP | SET_FLAG_COMP;
    desc_h2c_p->length = length;
    desc_h2c_p->addr_src_lo = PP_ADDR_LO(sa);
    desc_h2c_p->addr_src_hi = PP_ADDR_HI(sa);
    desc_h2c_p->addr_dst_lo = PP_ADDR_LO(overhead_a);
    desc_h2c_p->addr_dst_hi = PP_ADDR_HI(overhead_a);
    desc_h2c_p->next_lo = 0;
    desc_h2c_p->next_hi = 0;

    gwbar0->h2c[0].addr_desc_lo = PP_ADDR_LO(desc_h2c_a);
    gwbar0->h2c[0].addr_desc_hi = PP_ADDR_HI(desc_h2c_a);
    gwbar0->h2c[0].addr_poll_lo = PP_ADDR_LO(poll_h2c_a);
    gwbar0->h2c[0].addr_poll_hi = PP_ADDR_HI(poll_h2c_a);
    gwbar0->h2c[0].num_desc_adj = 0;

    if (DBG_INFO) {
        printf("Status_h2c: 0x%08x 0x%08x 0x%08x 0x%08x 0x%08x\n", *poll_h2c_p,
               gwbar0->h2c[0].ctrl, gwbar0->h2c[0].status0,
               gwbar0->h2c[0].desc_count, desc_h2c_p[0].flags);
        fflush(stdout);
    }

    // c2h

    volatile GowinDescriptor *desc_c2h_p = (GowinDescriptor *)proc->mem_dst;
    memset((void *)desc_c2h_p, 0, offset_poll);
    uint64_t desc_c2h_a = proc->dma_dst;

    volatile uint32_t *poll_c2h_p = (uint32_t *)(proc->mem_dst + offset_poll);
    *poll_c2h_p = 0;
    uint64_t poll_c2h_a = proc->dma_dst + offset_poll;

    volatile uint32_t *write_back_p = (uint32_t *)(proc->mem_dst + offset_oh_wb);
    *write_back_p = 0;
    uint64_t write_back_a = proc->dma_dst + offset_oh_wb;

    volatile uint8_t *dp = proc->mem_dst + offset_data;
    uint64_t da = proc->dma_dst + offset_data;

    if (DBG_INFO) {
        printf("*** Init: %i descriptors ***\n", num_descs);
    }

    desc_c2h_p->flags = SET_FLAG_STOP | SET_FLAG_EOP | SET_FLAG_COMP;
    desc_c2h_p->length = length;
    desc_c2h_p->addr_src_lo = PP_ADDR_LO(write_back_a);
    desc_c2h_p->addr_src_hi = PP_ADDR_HI(write_back_a);
    desc_c2h_p->addr_dst_lo = PP_ADDR_LO(da);
    desc_c2h_p->addr_dst_hi = PP_ADDR_HI(da);
    desc_c2h_p->next_lo = 0;
    desc_c2h_p->next_hi = 0;

    gwbar0->c2h[0].addr_desc_lo = PP_ADDR_LO(desc_c2h_a);
    gwbar0->c2h[0].addr_desc_hi = PP_ADDR_HI(desc_c2h_a);
    gwbar0->c2h[0].addr_poll_lo = PP_ADDR_LO(poll_c2h_a);
    gwbar0->c2h[0].addr_poll_hi = PP_ADDR_HI(poll_c2h_a);
    gwbar0->c2h[0].num_desc_adj = 0;

    if (DBG_INFO) {
        printf("Status_c2h: 0x%08x 0x%08x 0x%08x 0x%08x 0x%08x\n", *poll_c2h_p,
               gwbar0->c2h[0].ctrl, gwbar0->c2h[0].status0,
               gwbar0->c2h[0].desc_count, desc_c2h_p[0].flags);
        fflush(stdout);
    }

    // control

    gwbar0->c2h[0].ctrl = SGDMA_START_POLL_DUPL;
    gwbar0->h2c[0].ctrl = SGDMA_START_POLL_DUPL;

    int timeout = TIMEOUT_POLL;
    while (timeout-- > 0 && !flag_exit) {
        if (DBG_INFO) {
            printf("Status_h2c: 0x%08x 0x%08x 0x%08x 0x%08x 0x%08x\n", *poll_h2c_p,
                   gwbar0->h2c[0].ctrl, gwbar0->h2c[0].status0,
                   gwbar0->h2c[0].desc_count, desc_h2c_p[0].flags);
            printf("Status_c2h: 0x%08x 0x%08x 0x%08x 0x%08x 0x%08x\n", *poll_c2h_p,
                   gwbar0->c2h[0].ctrl, gwbar0->c2h[0].status0,
                   gwbar0->c2h[0].desc_count, desc_c2h_p[0].flags);
            fflush(stdout);
        }
        if (*poll_h2c_p && *poll_c2h_p) {
            break;
        }
        usleep(1);
    }
    if (timeout <= 0) {
        printf(
            "timeout: poll_h2c=0x%08x poll_c2h=0x%08x h2c_count=%u c2h_count=%u\n",
            *poll_h2c_p, *poll_c2h_p, gwbar0->h2c[0].desc_count,
            gwbar0->c2h[0].desc_count);
    }

    gwbar0->h2c[0].ctrl = SGDMA_STOP;
    gwbar0->c2h[0].ctrl = SGDMA_STOP;

    if (flag_exit) {
        dest_proc(proc);
        return 1;
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
