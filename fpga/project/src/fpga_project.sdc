create_clock -name div_clk -period 10 -waveform {0 5} [get_pins {uut_div2/CLKOUT}]
create_clock -name ddr_clk_out -period 10 -waveform {0 5} [get_pins {u_ddr3/gw3_top/u_GW_DDR3_PHY_MC/u_ddr_phy_top/fclkdiv/CLKOUT}]
create_clock -name memory_clk -period 2.5 -waveform {0 1.25} [get_nets {memory_clk}]

# set_clock_groups -asynchronous -group [get_clocks {div_clk}] -group [get_clocks {ddr_clk_out}] -group [get_clocks {memory_clk}] 
set_clock_groups -asynchronous -group [get_clocks {ddr_clk_out}] -group [get_clocks {memory_clk}]
