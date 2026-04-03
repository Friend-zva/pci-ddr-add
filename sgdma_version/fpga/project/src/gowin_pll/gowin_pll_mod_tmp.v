//Copyright (C)2014-2026 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12.02
//IP Version: 1.0
//Part Number: GW5AST-LV138FPG676AC1/I0
//Device: GW5AST-138
//Device Version: B
//Created Time: Fri Apr  3 16:31:41 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    Gowin_PLL_MOD your_instance_name(
        .lock(lock), //output lock
        .clkout0(clkout0), //output clkout0
        .clkin(clkin), //input clkin
        .reset(reset), //input reset
        .icpsel(icpsel), //input [5:0] icpsel
        .lpfres(lpfres), //input [2:0] lpfres
        .lpfcap(lpfcap) //input [1:0] lpfcap
    );

//--------Copy end-------------------
