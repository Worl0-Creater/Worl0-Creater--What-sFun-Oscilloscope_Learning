//Copyright (C)2014-2024 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.10.02
//Part Number: GW2A-LV18PG256C8/I7
//Device: GW2A-18
//Device Version: C
//Created Time: Fri Apr  4 23:48:30 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	DDS_II_Top your_instance_name(
		.clk_i(clk_i), //input clk_i
		.rst_n_i(rst_n_i), //input rst_n_i
		.phase_valid_i(phase_valid_i), //input phase_valid_i
		.phase_inc_i(phase_inc_i), //input [31:0] phase_inc_i
		.phase_out_o(phase_out_o), //output [31:0] phase_out_o
		.sine_o(sine_o), //output [9:0] sine_o
		.data_valid_o(data_valid_o) //output data_valid_o
	);

//--------Copy end-------------------
