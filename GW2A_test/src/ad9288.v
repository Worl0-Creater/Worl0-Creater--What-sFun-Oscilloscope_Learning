`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// AD9288
//  - 双路采样器：输入为 signed 8-bit，偏移 127 后转为无符号。
//  - 输出同步到 clk，方便后级 Filter 使用。
//------------------------------------------------------------------------------
module AD9288(
    input clk,
    input rst_n,
    input signed [7:0] AD9288_DIN_A,
    input signed [7:0] AD9288_DIN_B,
    output wire AD9288_CLK_A,
    output wire AD9288_CLK_B,
    output reg [7:0] AD9288_DOUT_A,
    output reg [7:0] AD9288_DOUT_B
);
    
assign AD9288_CLK_A = clk;
assign AD9288_CLK_B = clk;

wire [7:0] DIN_A = $unsigned(AD9288_DIN_A + 8'd127);//signed to unsigned
wire [7:0] DIN_B = $unsigned(AD9288_DIN_B + 8'd127);
    
//------------------------------------------------------------------------------
// 通道 A：signed → unsigned → 时钟同步
//------------------------------------------------------------------------------
always @(posedge clk) begin
    if (!rst_n) begin
        AD9288_DOUT_A <= 0;
    end
    else begin
        AD9288_DOUT_A <= DIN_A;      
    end
end

//------------------------------------------------------------------------------
// 通道 B：与 A 同步处理
//------------------------------------------------------------------------------
always @(posedge clk) begin
    if (!rst_n) begin
        AD9288_DOUT_B <= 0;
    end
    else begin
        AD9288_DOUT_B <= DIN_B;      
    end
end
    
endmodule



