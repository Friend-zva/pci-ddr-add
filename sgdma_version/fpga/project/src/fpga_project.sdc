create_clock -name sysclk -period 10 -waveform {0 5} [get_pins {u_Gowin_PLL/u_pll/PLL_inst/CLKOUT0}]
create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]

#create_clock -name clk_x1 -period 10 -waveform {0 5} [get_pins {u_ddr3/gw3_top/u_ddr_phy_top/fclkdiv/CLKOUT}]
#set_clock_groups -asynchronous -group [get_clocks {sysclk}] -group [get_clocks {clk_x1}]
