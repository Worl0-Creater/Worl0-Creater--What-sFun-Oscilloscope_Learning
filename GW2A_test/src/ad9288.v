`timescale  1ns/1ps
//AD 9288 dual ADC signed 8bit, plus 127 to unsigned
// synchorize out to clk ,Facilitates filtering by the subsequent circuit stages
module  AD9288 (
    input               clk,
    input               rst_n,
    input signed [7:0]  AD9288_DIN_A,
    input signed [7:0]  AD9288_DIN_B,

    output wire         AD9288_CLK_A,
    output wire         AD9288_CLK_B,
    
    output reg[7:0]   AD9288_DOUT_A,
    output reg[7:0]   AD9288_DOUT_B
    );  
    assign AD9288_CLK_A = clk;
    assign AD9288_CLK_B = clk;
    
    wire [7:0] DIN_A = $unsigned (AD9288_DIN_A + 8'd127);
    wire [7:0] DIN_B = $unsigned (AD9288_DIN_B + 8'd127);
    

    //Channel A signed + unsigned -> synchornize clk
    always @( posedge clk) begin
        if(!rst_n)begin
            AD9288_DOUT_A <=0;
        end else begin
            AD9288_DOUT_A <= DIN_A;
        end
    end
    
    //Channel B signed + unsigned -> synchornize clk
    always @( posedge clk) begin
        if(!rst_n)begin
            AD9288_DOUT_B <=0;
        end else begin
            AD9288_DOUT_B <= DIN_B;
        end
    end
    
endmodule