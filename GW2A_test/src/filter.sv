module Average_Filter
#(
	parameter AVE_DATA_NUM = 5'd8,
	parameter AVE_DATA_BIT = 5'd3
)
(
	input rst_n,
	input clk,
	input [7:0] din,
	output [7:0] dout
);

reg [7:0] data_reg [AVE_DATA_NUM-1:0];

always @ (posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        data_reg[0] <= 0;
        data_reg[1] <= 0;
        data_reg[2] <= 0;
        data_reg[3] <= 0;
        data_reg[4] <= 0;
        data_reg[5] <= 0;
        data_reg[6] <= 0;
        data_reg[7] <= 0;
    end 
    else begin
        data_reg[0] <= din;
        data_reg[1] <= data_reg[0];
        data_reg[2] <= data_reg[1];
        data_reg[3] <= data_reg[2];
        data_reg[4] <= data_reg[3];
        data_reg[5] <= data_reg[4];
        data_reg[6] <= data_reg[5];
        data_reg[7] <= data_reg[6];
    end
end

//wire [11:0] sum0, sum1, sum2, sum3, sum4, sum5, sum6;
//Adder_Subtractor_Top u0 (.data_a(data_reg[0]), .data_b(data_reg[1]), .result(sum0));
//Adder_Subtractor_Top u1 (.data_a(data_reg[2]), .data_b(data_reg[3]), .result(sum1));
//Adder_Subtractor_Top u2 (.data_a(data_reg[4]), .data_b(data_reg[5]), .result(sum2));
//Adder_Subtractor_Top u3 (.data_a(data_reg[6]), .data_b(data_reg[7]), .result(sum3));
//Adder_Subtractor_Top u4 (.data_a(sum0), .data_b(sum1), .result(sum4));
//Adder_Subtractor_Top u5 (.data_a(sum2), .data_b(sum3), .result(sum5));
//Adder_Subtractor_Top u6 (.data_a(sum4), .data_b(sum5), .result(sum6));


wire [11:0] sum = data_reg[0] + data_reg[1] + data_reg[2] + data_reg[3] + data_reg[4] + data_reg[5] + data_reg[6] + data_reg[7]; //将最老的数据换为最新的输入数据
assign dout = sum >> AVE_DATA_BIT; //右移3 等效为÷8

endmodule
