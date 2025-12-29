//------------------------------------------------------------------------------
// reg_decode
//  - 将 SPI 写入的寄存器阵列 regs[] 解码为核心控制信号与 LCD 显示字符串。
//  - 每个寄存器下标固定对应一组前端控件/数值，参见各段的“寄存器映射”注释。
//------------------------------------------------------------------------------
module reg_decode(
    input clk,
    input rst_n,
    input [15:0] regs [31:0],

	input [31:0] measure_freq,
	output wire [(12*8-1):0] dis_measure_freq_buff,

	output wire ch,
	output wire [(10*8-1):0] dis_ch_buff,
	output wire pause,
    input stop,
	output wire [(4*8-1):0] dis_stop_buff,
	output wire acdc,
	output wire [(2*8-1):0] dis_acdc_buff,

	output wire trig_ch,
	output wire [(3*8-1):0] dis_trig_ch_buff,
	output wire trig_edge,
	output wire [(3*8-1):0] dis_trig_edge_buff,
	output wire [1:0] trig_mode,
	output wire [(6*8-1):0] dis_trig_mode_buff,
	output wire [7:0] trig_level,
	output wire [(3*8-1):0] dis_trig_level_buff,

	output wire [15:0] time_gear,
	output reg  [(9*8-1):0] dis_time_gear_buff,
	output wire [15:0] time_offset,
	output wire [(9*8-1):0] dis_time_offset_buff,
	output wire [15:0] step,

	output wire [15:0] ch1_gear,
	output reg [(10*8-1):0] dis_ch1_gear_buff,
	output wire [15:0] ch1_offset,
	output wire [(3*8-1):0] dis_ch1_offset_buff,
	output wire [15:0] ch2_gear,
	output reg [(10*8-1):0] dis_ch2_gear_buff,
	output wire [15:0] ch2_offset,
	output wire [(3*8-1):0] dis_ch2_offset_buff,

	output wire [7:0] dac_wave,
	output reg [(8*8-1):0] dis_dac_wave_buff,
	output wire [31:0] dac_freq_poff,
	output wire [31:0] dac_freq,
    output wire [15:0] number_ch,
	output wire [(10*8-1):0] dis_dac_freq_buff,
	output wire [7:0] dac_att,
	output reg [(6*8-1):0] dis_dac_att_buff,

	output wire [15:0] y1,
	output wire [(6*8-1):0] dis_y1_buff,
	output wire [15:0] y2,
	output wire [(6*8-1):0] dis_y2_buff,
	output wire [15:0] dy,
	output wire [(6*8-1):0] dis_dy_buff,
	output wire [15:0] x1,
	output wire [(6*8-1):0] dis_x1_buff,
	output wire [15:0] x2,
	output wire [(6*8-1):0] dis_x2_buff,
	output wire [15:0] dx,
	output wire [(6*8-1):0] dis_dx_buff,
	output wire [1:0] cursor_mode,

	output wire [15:0] object
);
/************************当前控件**************************/
assign object = regs[14];



/**************************光标**************************/
assign y1 = regs[10];
assign y2 = regs[11];
assign x1 = regs[12];
assign x2 = regs[13];
assign cursor_mode = regs[1][14:13];

assign dis_y1_buff=0;
assign dis_y2_buff=0;
assign dis_dy_buff=0;
assign dis_x1_buff=0;
assign dis_x2_buff=0;
assign dis_dx_buff=0;
assign dx=0;
assign dy=0;

/***********************DAC调节**************************/
assign dac_wave = regs[15][7:0];
assign dac_freq_poff = {regs[17],regs[16]};
assign dac_freq = {regs[19],regs[18]};
assign dac_att = regs[15][15:8];
assign number_ch = regs[20];

always@(*)begin
	case(dac_wave)
		0: begin dis_dac_wave_buff = "SINE    "; end
		1: begin dis_dac_wave_buff = "SQUARE  "; end
		2: begin dis_dac_wave_buff = "TRIANGLE"; end
		default: begin dis_dac_wave_buff = "SINE    "; end
	endcase
end

always@(*)begin
	case(dac_att)
		0: begin dis_dac_att_buff = "1/1Vpp"; end
		1: begin dis_dac_att_buff = "7/8Vpp"; end
		2: begin dis_dac_att_buff = "3/4Vpp"; end
		3: begin dis_dac_att_buff = "5/8Vpp"; end
		4: begin dis_dac_att_buff = "1/2Vpp"; end
		5: begin dis_dac_att_buff = "3/8Vpp"; end
		6: begin dis_dac_att_buff = "1/4Vpp"; end
		7: begin dis_dac_att_buff = "1/8Vpp"; end
		default: begin dis_dac_att_buff = "1/1Vpp"; end
	endcase
end

wire [3:0] dis_dac_freq_unit;
wire [3:0] dis_dac_freq_ten;
wire [3:0] dis_dac_freq_hun;
wire [3:0] dis_dac_freq_tho;	
wire [3:0] dis_dac_freq_t_tho;
wire [3:0] dis_dac_freq_h_hun;
wire [3:0] dis_dac_freq_mil;
wire [3:0] dis_dac_freq_t_mil;
assign dis_dac_freq_buff = {4'd0,dis_dac_freq_t_mil,4'd0,dis_dac_freq_mil,4'd0,dis_dac_freq_h_hun,
							4'd0,dis_dac_freq_t_tho,4'd0,dis_dac_freq_tho,4'd0,dis_dac_freq_hun,
							4'd0,dis_dac_freq_ten,  4'd0,dis_dac_freq_unit,"Hz"};//每8位对应一个字符
wire [31:0] dac_freq_t = dac_freq >> 2;
bcd_8421 bcd_8421_5(
	.sys_clk(clk),   
    .sys_rst_n(rst_n),   
    .data(dac_freq_t),   
    .unit(dis_dac_freq_unit),  
    .ten(dis_dac_freq_ten),  
    .hun(dis_dac_freq_hun),   
    .tho(dis_dac_freq_tho), 
    .t_tho(dis_dac_freq_t_tho),   
    .h_hun(dis_dac_freq_h_hun),   
    .mil(dis_dac_freq_mil),   
    .t_mil(dis_dac_freq_t_mil)    
);

/**********************垂直调节**************************/
assign ch1_gear = regs[2];
assign ch1_offset = regs[4];
assign ch2_gear = regs[3];
assign ch2_offset = regs[5];

always@(*)begin
	case(ch1_gear)
		0: begin dis_ch1_gear_buff = {8'd16,"  5mV/div"}; end
		1: begin dis_ch1_gear_buff = {8'd16," 10mV/div"}; end
		2: begin dis_ch1_gear_buff = {8'd16," 20mV/div"}; end
		3: begin dis_ch1_gear_buff = {8'd16," 50mV/div"}; end
		4: begin dis_ch1_gear_buff = {8'd16,"100mV/div"}; end
		5: begin dis_ch1_gear_buff = {8'd16,"200mV/div"}; end
		6: begin dis_ch1_gear_buff = {8'd16,"500mV/div"}; end
		7: begin dis_ch1_gear_buff = {8'd16,"   1V/div"}; end
		8: begin dis_ch1_gear_buff = {8'd16,"   2V/div"}; end
		9: begin dis_ch1_gear_buff = {8'd16,"   5V/div"}; end
		default: begin dis_ch1_gear_buff = "  5mV/div"; end
	endcase
end

always@(*)begin
	case(ch2_gear)
		0: begin dis_ch2_gear_buff = {8'd17,"  5mV/div"}; end
		1: begin dis_ch2_gear_buff = {8'd17," 10mV/div"}; end
		2: begin dis_ch2_gear_buff = {8'd17," 20mV/div"}; end
		3: begin dis_ch2_gear_buff = {8'd17," 50mV/div"}; end
		4: begin dis_ch2_gear_buff = {8'd17,"100mV/div"}; end
		5: begin dis_ch2_gear_buff = {8'd17,"200mV/div"}; end
		6: begin dis_ch2_gear_buff = {8'd17,"500mV/div"}; end
		7: begin dis_ch2_gear_buff = {8'd17,"   1V/div"}; end
		8: begin dis_ch2_gear_buff = {8'd17,"   2V/div"}; end
		9: begin dis_ch2_gear_buff = {8'd17,"   5V/div"}; end
		default: begin dis_ch2_gear_buff = "  5mV/div"; end
	endcase
end

wire [3:0]				dis_ch1_offset_unit;
wire [3:0]				dis_ch1_offset_ten;
wire [3:0]				dis_ch1_offset_hun;
assign dis_ch1_offset_buff ={4'd0,dis_ch1_offset_hun,4'd0,dis_ch1_offset_ten,4'd0,dis_ch1_offset_unit};
wire [7:0] ch1_offset_1=ch1_offset>>2;
bcd_8421 bcd_8421_4(
	.sys_clk(clk),   
    .sys_rst_n(rst_n),   
    .data(ch1_offset_1),   
    .unit(dis_ch1_offset_unit),  
    .ten(dis_ch1_offset_ten),  
    .hun(dis_ch1_offset_hun)      
);

wire [3:0]				dis_ch2_offset_unit;
wire [3:0]				dis_ch2_offset_ten;
wire [3:0]				dis_ch2_offset_hun;
assign dis_ch2_offset_buff ={4'd0,dis_ch2_offset_hun,4'd0,dis_ch2_offset_ten,4'd0,dis_ch2_offset_unit};
wire [7:0] ch2_offset_1=ch2_offset>>2;
bcd_8421 bcd_8421_3(
	.sys_clk(clk),   
    .sys_rst_n(rst_n),   
    .data(ch2_offset_1),   
    .unit(dis_ch2_offset_unit),  
    .ten(dis_ch2_offset_ten),  
    .hun(dis_ch2_offset_hun)      
);


/**********************水平调节**************************/
assign time_gear = regs[7];
assign time_offset = regs[8];
assign step = regs[9]==0?1:regs[9];

always@(*)begin
	case(time_gear)
		1:	begin dis_time_gear_buff = "500ns/div"; end//100Mbps
		2:	begin dis_time_gear_buff = "  1us/div"; end//100Mbps
		3:	begin dis_time_gear_buff = "  2us/div"; end//100Mbps
		4:	begin dis_time_gear_buff = "  5us/div"; end//100Mbps
		5:	begin dis_time_gear_buff = " 10us/div"; end//100Mbps
		6:	begin dis_time_gear_buff = " 20us/div"; end//100Mbps
		7:	begin dis_time_gear_buff = " 50us/div"; end//25Mbps
		8:	begin dis_time_gear_buff = "100us/div"; end//20Mbps
		9:	begin dis_time_gear_buff = "200us/div"; end//10Mbps
		10:	begin dis_time_gear_buff = "500us/div"; end//4Mbps
		11:	begin dis_time_gear_buff = "  1ms/div"; end//2Mbps
		12:	begin dis_time_gear_buff = "  2ms/div"; end//1Mbps
		13:	begin dis_time_gear_buff = "  5ms/div"; end//400kbps
		14:	begin dis_time_gear_buff = " 10ms/div"; end//200kbps
		15:	begin dis_time_gear_buff = " 20ms/div"; end//100kbps
		16:	begin dis_time_gear_buff = " 50ms/div"; end//40kbps
		17:	begin dis_time_gear_buff = "100ms/div"; end//20kbps
		18:	begin dis_time_gear_buff = "200ms/div"; end//10kbps
		19:	begin dis_time_gear_buff = "500ms/div"; end//4kbps
		20:	begin dis_time_gear_buff = "   1s/div"; end//2kbps
		default: begin dis_time_gear_buff = "500ns/div"; end//100Mbps
	endcase
end

assign dis_time_offset_buff=0;

/**********************测量频率**************************/
wire [3:0]				dis_freq_unit;
wire [3:0]				dis_freq_ten;
wire [3:0]				dis_freq_hun;
wire [3:0]				dis_freq_tho;	
wire [3:0]				dis_freq_t_tho;
wire [3:0]				dis_freq_h_hun;
wire [3:0]				dis_freq_mil;
wire [3:0]				dis_freq_t_mil;
assign dis_measure_freq_buff ={"F:",4'd0,dis_freq_t_mil,4'd0,dis_freq_mil,4'd0,dis_freq_h_hun,4'd0,dis_freq_t_tho,4'd0,dis_freq_tho,4'd0,dis_freq_hun,4'd0,dis_freq_ten,4'd0,dis_freq_unit,"Hz"};//每8位对应一个字符
bcd_8421 bcd_8421_2(
	.sys_clk(clk),   
    .sys_rst_n(rst_n),   
    .data(measure_freq),   
    .unit(dis_freq_unit),  
    .ten(dis_freq_ten),  
    .hun(dis_freq_hun),   
    .tho(dis_freq_tho), 
    .t_tho(dis_freq_t_tho),   
    .h_hun(dis_freq_h_hun),   
    .mil(dis_freq_mil),   
    .t_mil(dis_freq_t_mil)    
);


/****活跃通道****/
assign ch = regs[0][1];
assign dis_ch_buff = ch?"ACTIVE:CH2":"ACTIVE:CH1";

/****运行/停止****/
assign pause = regs[1][4];
assign dis_stop_buff = !stop?"STOP":"RUN ";
    //------------------------------------------------------------------------------
    // 触发通道设置
    //  - regs[1][3] : 触发通道选择位。
    //  - regs[0][0] : AC/DC 耦合选项。
    //  - regs[1][2] : 触发边沿（上升/下降）。
    //  - regs[1][1:0] : 触发模式。
    //------------------------------------------------------------------------------
	assign trig_ch = regs[1][3];
	assign dis_trig_ch_buff = trig_ch?"CH2":"CH1";

	/****耦合方式****/
	assign acdc = regs[0][0];
	assign dis_acdc_buff = acdc?"AC":"DC";

	/****触发边沿****/
	assign trig_edge = regs[1][2];
	assign dis_trig_edge_buff = trig_edge?"NEG":"POS";

	/****触发模式****/
	assign trig_mode = regs[1][1:0];
	assign dis_trig_mode_buff = (trig_mode==2'b0)?"AUTO  ":((trig_mode==2'b01)?"NORMAL":"SINGLE");

	/****触发电平****/
	assign trig_level = regs[6][7:0];
	wire [3:0] trig_level_unit;
	wire [3:0] trig_level_ten;
	wire [3:0] trig_level_hun;
	wire [8:0] trig_level_1=trig_level>>2;
	bcd_8421 bcd_8421_1(
		.sys_clk(clk),   
	    .sys_rst_n(rst_n),   
	    .data(trig_level_1),   
	    .unit(trig_level_unit),  
	    .ten(trig_level_ten),  
	    .hun(trig_level_hun)    
	);
	assign dis_trig_level_buff = {4'd0,trig_level_hun,4'd0,trig_level_ten,4'd0,trig_level_unit};
endmodule