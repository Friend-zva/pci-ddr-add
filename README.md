# PCIe SGDMA + DDR3 + Adder Demo for Sipeed Tang Mega 138K Pro

This project is a demonstration of SerDes, PCIe SGDMA, and DDR3 memory on the Sipeed [Tang Mega 138K Pro Dock](https://wiki.sipeed.com/hardware/en/tang/tang-mega-138k/mega-138k-pro.html).

## Main Features

- **PCIe Gen3 x4**: High-speed data transmission.
- **GOWIN PCIe SGDMA IP**: Supports Scatter-Gather DMA (H2C and C2H channels).
- **DDR3 Memory**: Initialization and testing of onboard memory (2x H5TQ4G63EFR-RDC).
- **Hardware Adder**: Computational core directly accessing memory via AXI.
- **AXI Interconnect**: Merges data flows from PCIe and Logic core for DDR3 access.
- **Driver & Program**: Adder testing with Linux PCIe driver and demo application.

## Project Structure

```text
| -- fpga/                    --> FPGA source code
|    |-- fpga_project.fs.7z   --> Prebuild bitstream (zipped)
|    |-- fpga_project.gar     --> Archived project
|    `-- project/             --> Gowin IDE project
|    
| -- host/                    --> Host software
|    |-- driver/              --> PCIe driver
|    |-- apps/                --> Demo app for testing
|    `-- Makefile             --> Main build script for driver and apps
```

## How to Use

### Prerequisites

- **Gowin IDE**: Version >= 1.9.12.02 recommended.
- **Linux Environment**: Ubuntu 20.04/22.04 recommended.
- **Boot Configuration**:
  - `pci=realloc=on`, `iommu=pt` (add to GRUB).
  - **Secure Boot**: Must be **Disabled**. Unsigned kernel modules (like this custom driver) will be blocked by UEFI Secure Boot unless you manually sign them and enroll the key in MOK.

### Build & Load FPGA

1. Open the project in Gowin IDE: `fpga/project/fpga_project.gprj`.
2. Verify **Project-Configuration**:
   - **Place**: Place option: 4, SerDes Retiming: True.
   - **Route**: Route Order: 1, Route option: 1.
   - **Dual-Purpose Pin**: Enable `Use SSPI as regular IO` and `Use CPU as regular IO`.
3. Synthesize and generate Bitstream (`.fs`).
4. Load to board via **Gowin Programmer** or **openFPGAloader**.
   *Note: On PC motherboards, program the board while the host is OFF, then boot the PC.*

### Build & Run Host Project

0. Check if the device is recognized: `sudo lspci -vvd 22c2:1100`.
1. Navigate to the `host/` directory: `cd host`.
2. Build the driver and applications: `sudo make`.
3. Run the tests: `./bin/run_demo`.

## LEDs & Buttons

Status indication on the Dock (LED0 is on the far right):

| LED  | Description                  | Expected State      |
| -----| ---------------------------- | ------------------- |
| LED0 | RUNNING INDICATOR            | BLINKING            |
| LED1 | PCIe RESET (L23)             | OFF (see note)      |
| LED2 | PCIe LOGIC START             | ON                  |
| LED3 | PCIe LINK UP                 | ON                  |
| LED4 | DDR3 Initialization Complete | ON                  |
| LED5 | PCIe h2c RUNNING             | OFF (ON after run)  |

> *NOTE: LED1 (PCIe RESET) may flash briefly during boot. If it stays ON, check your reset polarity or PULL_UP constraints.*

## Implementation Details

- **Initialization**: Uses a startup delay (`pcie_start`) to ensure power and clocks are stable before PCIe logic starts.
- **Clocks**:
  - `sys_clk` (200MHz) / `memory_clk` (400MHz) for DDR3 controller.
  - `tlp_clk` (100MHz) for PCIe TLP and AXI logic.
- **Interface**: BAR0 is used for SGDMA control, BAR2 is user-accessible for custom registers/adder control.

## Links

- [Tang MEGA 138K Pro Wiki](https://wiki.sipeed.com/hardware/en/tang/tang-mega-138k/mega-138k-pro.html)
- [Gowin PCIe IP User Guide](https://www.gowinsemi.com/upload/database_doc/2490/document/669a3b1d64272.pdf) & [PCIe DMA demo](https://github.com/sipeed/TangMega-138KPro-example/tree/main/pcie_dma_demo)
- [Gowin DDR3 IP User Guide](https://www.gowinsemi.com/upload/database_doc/2009/document/696a8c052f84e.pdf) & [DDR test](https://github.com/sipeed/TangMega-138KPro-example/tree/main/ddr_test)
- [Gowin SGDMA IP User Guide](https://www.gowinsemi.com/upload/database_doc/3345/document/69810ed812355.pdf)
- [Verilog-AXI (Alex Forencich)](https://github.com/alexforencich/verilog-axi)
