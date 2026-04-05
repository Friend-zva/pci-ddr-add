create_clock -name div_clk -period 10 -waveform {0 5} [get_pins {uut_div2/CLKOUT}]
