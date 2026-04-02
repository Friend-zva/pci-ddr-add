//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12 (64-bit)
//Part Number: GW5AT-LV60UG225C2/I1
//Device: GW5AT-60
//Device Version: B
//Created Time: Mon Nov  3 16:39:51 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	Uart_to_Bus_Top your_instance_name(
		.rst_n_i(rst_n_i), //input rst_n_i
		.clk_i(clk_i), //input clk_i
		.local0_wren_o(local0_wren_o), //output local0_wren_o
		.local0_addr_o(local0_addr_o), //output [15:0] local0_addr_o
		.local0_rden_o(local0_rden_o), //output local0_rden_o
		.local0_wdat_o(local0_wdat_o), //output [31:0] local0_wdat_o
		.local0_rdat_i(local0_rdat_i), //input [31:0] local0_rdat_i
		.local0_rdat_vld_i(local0_rdat_vld_i), //input local0_rdat_vld_i
		.local0_wdat_rdy_i(local0_wdat_rdy_i), //input local0_wdat_rdy_i
		.uart_rx_led_o(uart_rx_led_o), //output uart_rx_led_o
		.uart_tx_led_o(uart_tx_led_o), //output uart_tx_led_o
		.uart_rx_i(uart_rx_i), //input uart_rx_i
		.uart_tx_o(uart_tx_o) //output uart_tx_o
	);

//--------Copy end-------------------
