//------------------------------------------------------------------------------
// DAC
//  - 依据寄存器设置生成 DDS 波形，含幅度控制与查表输出。
//  - 与系统时钟同步，通过 dac_clk 输出至后级数模接口。
//------------------------------------------------------------------------------
module DAC(
    input clk,
    input rst_n,
    input [31:0] dac_freq_poff,
	input [7:0] attenuation_sel,
	input [7:0] wave_sel,
    output reg signed [9:0] DAC_out,
    output wire dac_clk
);

assign dac_clk = clk;
reg signed [9:0] DAC_out_r;
reg signed [9:0] wave_reg;


always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        DAC_out <= 0;
    else
        DAC_out <= DAC_out_r;
end

// 第一级：波形选择
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        wave_reg <= 10'd0;
    else
        case(wave_sel)
            0: wave_reg <= sine_wave;
            1: wave_reg <= square_wave;
            2: wave_reg <= triangle_wave;
            3: wave_reg <= tooth_wave;
            default: wave_reg <= sine_wave;
        endcase
end

// 第二级：衰减选择
// 衰减模块（第二、三级）
reg signed [9:0] temp_add1, temp_add2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        temp_add1 <= 10'd0;
        temp_add2 <= 10'd0;
    end else begin
        temp_add1 <= (wave_reg >>> 1) + (wave_reg >>> 2);
        temp_add2 <= (wave_reg >>> 3);
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        DAC_out_r <= 10'd0;
    else
        case (attenuation_sel)
            8'd0: DAC_out_r <= wave_reg;
            8'd1: DAC_out_r <= temp_add1 + temp_add2;
            8'd2: DAC_out_r <= temp_add1;
            8'd3: DAC_out_r <= (wave_reg >>> 1) + (wave_reg >>> 3);
            8'd4: DAC_out_r <= wave_reg >>> 1;
            8'd5: DAC_out_r <= (wave_reg >>> 2) + (wave_reg >>> 3);
            8'd6: DAC_out_r <= wave_reg >>> 2;
            8'd7: DAC_out_r <= wave_reg >>> 3;
            default: DAC_out_r <= wave_reg;
        endcase
end


/*****************************************************************************/
wire signed [9:0] tooth_wave = (dds_phase>>>22)-128;
wire signed [31:0] dds_phase;
reg signed [9:0] sine_wave; // 正弦输出

DDS_II_Top DDS_II_1(
	.clk_i(clk), //input clk_i
	.rst_n_i(rst_n), //input rst_n_i
	.phase_valid_i(1'b1), //input phase_valid_i
	.phase_inc_i(dac_freq_poff), //input [31:0] phase_inc_i
	.sine_o(sine_wave), //output signed [9:0] sine_o
    .phase_out_o(dds_phase),//output [31:0] phase_out_o
	.data_valid_o() //output data_valid_o
);

/*****************************************************************************/

reg signed [9:0] square_wave; // 方波输出

// 方波生成
always @(posedge clk) begin
    if (dds_phase[31:16] < 16'h8000) // 比较相位累加器的高 16 位
        square_wave <= 10'd511;  // 高电平（满量程）
    else
        square_wave <= -10'd512; // 低电平（满量程）
end

/*****************************************************************************/
wire signed [9:0] dds_phase_2 = dds_phase>>>22;
reg signed [9:0] triangle_wave;  // 10 位三角波输出

// 三角波生成
always @(posedge clk) begin
    if (dds_phase_2 >= 0) begin
        triangle_wave <= (dds_phase_2 - 12'd256)<<<1; // 映射到 -512 到 +511
    end else begin
        triangle_wave <= (12'd768 - dds_phase_2)<<<1; // 映射到 -512 到 +511
    end
end


endmodule
