//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.10.02 
//Created Time: 2025-04-12 01:02:45
create_clock -name clk_in -period 20 -waveform {0 10} [get_nets {clk_in}]
//create_clock -name clk_100 -period 10 -waveform {0 5} [get_nets {clk_100}]
//create_clock -name clkb -period 10 -waveform {0 5} [get_nets {clkb}]
//create_clock -name AD9288_CLK_B -period 10 -waveform {0 5} [get_ports {AD9288_CLK_B}]
//create_clock -name AD9288_CLK_A -period 10 -waveform {0 5} [get_ports {AD9288_CLK_A}]








