//------------------------------------------------------------------------------
// top
//  - 系统顶层：汇总时钟、SPI 配置、采集/显示/波形输出等子系统。
//  - 负责将寄存器 regs[] 分发至各模块，并协调显示刷新与 DAC。
//------------------------------------------------------------------------------
module top(
    input clk_in,
    input rst_n,

    input spi_cs,
    input spi_wr,
    input spi_sck,
    output spi_miso,
    input spi_mosi,
    input [13:0] key_in,

    output	wire		lcd_res,	//LCD液晶屏复位
    output	wire		lcd_dc,		//LCD数据指令控制
    output	wire [15:0]	lcd_data,	//LCD数据信号
    output  wire        lcd_rd,     //LCD读信号
    output  wire        lcd_wr,     //LCD写信号
    output  wire        lcd_cs,

    input [7:0] AD9288_DIN_A,
    input [7:0] AD9288_DIN_B,
    output AD9288_CLK_A,
    output AD9288_CLK_B,
	output wire dac_clk,
	output wire [9:0] dac_out
);

//------------------------------------------------------------------------------
// 参数与状态寄存器
//------------------------------------------------------------------------------
wire [15:0] step;
wire [15:0] time_gear;
wire [(9*8-1):0] dis_time_gear_buff;
wire [15:0] time_offset;
wire [(9*8-1):0] dis_time_offset_buff;

wire [31:0] measure_freq;
wire [(12*8-1):0] dis_measure_freq_buff;
wire ch;
wire [(10*8-1):0] dis_ch_buff;
wire stop;
wire [(4*8-1):0] dis_stop_buff;
wire pause;
wire trig_ch;
wire [(3*8-1):0] dis_trig_ch_buff;
wire acdc;
wire [(2*8-1):0] dis_acdc_buff;
wire trig_edge;
wire [(3*8-1):0] dis_trig_edge_buff;
wire [1:0] trig_mode;
wire [(6*8-1):0] dis_trig_mode_buff;
wire [7:0] trig_level;
wire [7:0] trig_level_1 = 255 - trig_level;
wire [(3*8-1):0] dis_trig_level_buff;

wire [15:0] ch1_gear;
wire [(10*8-1):0] dis_ch1_gear_buff;
wire [15:0] ch1_offset;
wire [(3*8-1):0] dis_ch1_offset_buff;
wire [15:0] ch2_gear;
wire [(10*8-1):0] dis_ch2_gear_buff;
wire [15:0] ch2_offset;
wire [(3*8-1):0] dis_ch2_offset_buff;

wire [7:0] dac_wave;
wire [(8*8-1):0] dis_dac_wave_buff;
wire [31:0] dac_freq_poff;
wire [31:0] dac_freq;
wire [15:0] number_ch;
wire [(10*8-1):0] dis_dac_freq_buff;
wire [7:0] dac_att;
wire [(6*8-1):0] dis_dac_att_buff;

wire [15:0] y1;
wire [(6*8-1):0] dis_y1_buff;
wire [15:0] y2;
wire [(6*8-1):0] dis_y2_buff;
wire [15:0] dy;
wire [(6*8-1):0] dis_dy_buff;
wire [15:0] x1;
wire [(6*8-1):0] dis_x1_buff;
wire [15:0] x2;
wire [(6*8-1):0] dis_x2_buff;
wire [15:0] dx;
wire [(6*8-1):0] dis_dx_buff;
wire [1:0] cursor_mode;
wire [15:0] object;

//------------------------------------------------------------------------------
// 采集信号
//------------------------------------------------------------------------------
wire [7:0] AD9288_DOUT_A_0;
wire [7:0] AD9288_DOUT_B_0;
wire [7:0] AD9288_DOUT_A;
wire [7:0] AD9288_DOUT_B;

wire signed [9:0] dac_out1;
assign dac_out = dac_out1 + 10'h200;

//------------------------------------------------------------------------------
// 触发与显示控制
//------------------------------------------------------------------------------
wire [13:0] trig_pos;
wire display_en;
wire display_done;
wire read_enable;
wire [7:0] ram_data_out_a;
wire [7:0] ram_data_out_b;
wire [14:0] ram_data_addr;

wire clk_100;//100M系统时钟

//------------------------------------------------------------------------------
// SPI 寄存器组 regs[]
//  - 通过 spi_slave 模块由 MCU 访问的 32×16bit 寄存器数组。
//  - regs[i] 的具体含义（配置项 / 状态位等）由 SPI 寄存器协议统一定义，
//    MCU 固件与 FPGA 顶层/子模块应保持一致的寄存器映射。
//  - 本顶层只负责将完整的 regs[] 数组传递给子模块，由各子模块按约定
//    解析所需的寄存器索引；新增/修改寄存器时请同时更新：
//       * SPI 寄存器协议文档
//       * MCU 端寄存器读写代码
//       * 使用 regs[] 的 FPGA 模块对照说明
//------------------------------------------------------------------------------
reg [15:0] regs [31:0];

//------------------------------------------------------------------------------
// 时钟与 SPI 配置
//------------------------------------------------------------------------------
Gowin_rPLL pll_1(
    .clkout(clk_100), 
    .reset(!rst_n), 
    .clkin(clk_in)
);


spi_slave spi_slave_u(
    .clk(clk_100),
    .SCK(spi_sck),
    .rst_n(rst_n),
    .MOSI(spi_mosi),
    .CS(spi_cs),
    .WR(spi_wr),
    .MISO(spi_miso),
    .regs(regs), //16位寄存器
    .key_in(key_in)
);

//------------------------------------------------------------------------------
// 寄存器解码与前端参数
//------------------------------------------------------------------------------
reg_decode reg_decode_1(
    .clk(clk_100),
    .rst_n(rst_n),
    .regs(regs),
	.measure_freq(measure_freq),
	.dis_measure_freq_buff(dis_measure_freq_buff),
	.ch(ch),
	.dis_ch_buff(dis_ch_buff),
	.pause(pause),
    .stop(stop),
	.dis_stop_buff(dis_stop_buff),
	.trig_ch(trig_ch),
	.dis_trig_ch_buff(dis_trig_ch_buff),
	.acdc(acdc),
	.dis_acdc_buff(dis_acdc_buff),
	.trig_edge(trig_edge),
	.dis_trig_edge_buff(dis_trig_edge_buff),
	.trig_mode(trig_mode),
	.dis_trig_mode_buff(dis_trig_mode_buff),
	.trig_level(trig_level),
	.dis_trig_level_buff(dis_trig_level_buff),
	.time_gear(time_gear),
	.dis_time_gear_buff(dis_time_gear_buff),
	.time_offset(time_offset),
	.dis_time_offset_buff(dis_time_offset_buff),
	.step(step),
	.ch1_gear(ch1_gear),
	.dis_ch1_gear_buff(dis_ch1_gear_buff),
	.ch1_offset(ch1_offset),
	.dis_ch1_offset_buff(dis_ch1_offset_buff),
	.ch2_gear(ch2_gear),
	.dis_ch2_gear_buff(dis_ch2_gear_buff),
	.ch2_offset(ch2_offset),
	.dis_ch2_offset_buff(dis_ch2_offset_buff),
	.dac_wave(dac_wave),
	.dis_dac_wave_buff(dis_dac_wave_buff),
	.dac_freq_poff(dac_freq_poff),
	.dac_freq(dac_freq),
    .number_ch(number_ch),
	.dis_dac_freq_buff(dis_dac_freq_buff),
	.dac_att(dac_att),
	.dis_dac_att_buff(dis_dac_att_buff),
	.y1(y1),
	.dis_y1_buff(dis_y1_buff),
	.y2(y2),
	.dis_y2_buff(dis_y2_buff),
	.dy(dy),
	.dis_dy_buff(dis_dy_buff),
	.x1(x1),
	.dis_x1_buff(dis_x1_buff),
	.x2(x2),
	.dis_x2_buff(dis_x2_buff),
	.dx(dx),
	.dis_dx_buff(dis_dx_buff),
	.cursor_mode(cursor_mode),
	.object(object)
);

//------------------------------------------------------------------------------
// 模数采集链路：AD9288 → 平滑滤波 → 数据处理/RAM
//------------------------------------------------------------------------------
AD9288 AD9288_1(
    .clk(clk_100),          // 连接系统时钟
    .rst_n(rst_n),      // 连接系统复位信号
    .AD9288_DIN_A(AD9288_DIN_A), // 连接 A 通道输入数据
    .AD9288_DIN_B(AD9288_DIN_B), // 连接 B 通道输入数据
    .AD9288_CLK_A(AD9288_CLK_A), // 连接 A 通道时钟输出
    .AD9288_CLK_B(AD9288_CLK_B), // 连接 B 通道时钟输出
    .AD9288_DOUT_A(AD9288_DOUT_A_0),
    .AD9288_DOUT_B(AD9288_DOUT_B_0)
);

Average_Filter Average_Filter_1(
    .clk(clk_100),
    .rst_n(rst_n), 
    .din(AD9288_DOUT_A_0),    
    .dout(AD9288_DOUT_A) 
);

Average_Filter Average_Filter_2(
    .clk(clk_100),
    .rst_n(rst_n), 
    .din(AD9288_DOUT_B_0),    
    .dout(AD9288_DOUT_B) 
);


data_handler data_handler_1(
    .clk(clk_100),
	.clkb(clk_100),
    .rst_n(rst_n),
    .ad_data_a(AD9288_DOUT_A),
	.ad_data_b(AD9288_DOUT_B),
    .rate_select(time_gear),
	.ch(ch),
	.trig_ch(trig_ch),
    .trig_level(trig_level),
    .trig_edge(trig_edge),
    .trig_mode(trig_mode),
	.pause(pause),
	.stop(stop),
	.measure_freq(measure_freq),

	.display_en(display_en),
	.display_done(display_done),

	.trig_pos(trig_pos), 
    .read_enable(read_enable),
    .ram_data_out_a(ram_data_out_a),
	.ram_data_out_b(ram_data_out_b),
    .ram_data_addr(ram_data_addr)
);

//------------------------------------------------------------------------------
// 显示与波形/DAC 输出
//------------------------------------------------------------------------------
LCD LCD_1(
    .clk(clk_100),		
    .rst_n(rst_n),		
    .lcd_res(lcd_res),	
    .lcd_dc(lcd_dc),		
    .lcd_data(lcd_data),	
    .lcd_rd(lcd_rd),   
    .lcd_wr(lcd_wr),  
    .lcd_cs(lcd_cs),

	.stop(stop),
	.trig_pos(trig_pos),
	.ram_addr(ram_data_addr),
	.ram_en(read_enable),
	.ram_data_a(ram_data_out_a),
	.ram_data_b(ram_data_out_b),
	.display_en(display_en),
    .display_done(display_done),

	.trig_level(trig_level_1),
	.dis_measure_freq_buff(dis_measure_freq_buff),
	.dis_ch_buff(dis_ch_buff),
	.dis_stop_buff(dis_stop_buff),
	.dis_trig_ch_buff(dis_trig_ch_buff),
	.dis_acdc_buff(dis_acdc_buff),

	.dis_trig_edge_buff(dis_trig_edge_buff),
	.dis_trig_mode_buff(dis_trig_mode_buff),
	.dis_trig_level_buff(dis_trig_level_buff),

	.step(step),
	.dis_time_gear_buff(dis_time_gear_buff),
	.dis_time_offset_buff(dis_time_offset_buff),

	.dis_ch1_gear_buff(dis_ch1_gear_buff),
	.dis_ch1_offset_buff(dis_ch1_offset_buff),
	.dis_ch2_gear_buff(dis_ch2_gear_buff),
	.dis_ch2_offset_buff(dis_ch2_offset_buff),

	.dis_dac_wave_buff(dis_dac_wave_buff),
	.dis_dac_freq_buff(dis_dac_freq_buff),
	.dis_dac_att_buff(dis_dac_att_buff),

	.dis_y1_buff(dis_y1_buff),
	.dis_y2_buff(dis_y2_buff),
	.dis_dy_buff(dis_dy_buff),
	.dis_x1_buff(dis_x1_buff),
	.dis_x2_buff(dis_x2_buff),
	.dis_dx_buff(dis_dx_buff),
	.cursor_mode(cursor_mode),
    .number_ch(number_ch),
	.object(object)
);



DAC DAC_1(
    .clk(clk_100),
    .rst_n(rst_n),
    .dac_freq_poff(dac_freq_poff),
	.attenuation_sel(dac_att),
	.wave_sel(dac_wave),
    .DAC_out(dac_out1),
    .dac_clk(dac_clk)
);









endmodule