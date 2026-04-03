create_clock -name sysclk -period 10 -waveform {0 5} [get_pins {u_Gowin_PLL/u_pll/PLL_inst/CLKOUT0}]
create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]
