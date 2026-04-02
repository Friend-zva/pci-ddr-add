//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2025-10-21 16:01:45
create_clock -name sysclk -period 10 -waveform {0 5} [get_pins {u_Gowin_PLL/u_pll/PLLA_inst/CLKOUT0}]
create_clock -name tck_pad_i -period 50 -waveform {0 25} [get_ports {tck_pad_i}]
create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]
set_clock_groups -asynchronous -group [get_clocks {tck_pad_i}] -group [get_clocks {sysclk}]
