//Copyright (C)2014-2024 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.10.02
//Part Number: GW2A-LV55PG484C8/I7
//Device: GW2A-55
//Device Version: C
//Created Time: Fri Nov  1 14:53:56 2024

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    SPI7001_25M_1M_rPLL your_instance_name(
        .clkout(clkout), //output clkout
        .clkoutd(clkoutd), //output clkoutd
        .clkin(clkin) //input clkin
    );

//--------Copy end-------------------