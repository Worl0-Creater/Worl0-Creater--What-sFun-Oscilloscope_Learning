module  bcd_8421 (
    input wire                 sys_clk, // @100Mhz
    input wire                 sys_rst_n,
    input wire [31:0]          data,

    output reg [3:0]           unit,// bcd 个位
    output reg [3:0]           ten,// bcd 十位
    output reg [3:0]           hun,// bcd 百位
    output reg [3:0]           tho,// bcd 千位
    output reg [3:0]           t_tho,// bcd 万位
    output reg [3:0]           h_hun,// bcd 十万位
    output reg [3:0]           mil,// bcd 百万位
    output reg [3:0]           t_mil,// bcd 千万位 
);

//parameters and internal sigs

 [4:0] cnt_shift;       //移位 判断计数器
 [63:0] data_shift;     //移位 数据寄存器，拓展到64bit
 shift_flag;            //移位 标志符号
 //cnt_shift 跟踪27次迭代

 always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        cnt_shift <=5'd0;
    end else if((cnt_shift == 5'd27)&& (shift_flag))begin
        cnt_shift <=5'd0;
    end else if(shift_flag)begin
        cnt_shift <= cnt_shift + 1'd1;
    end else begin
        cnt_shift <= cnt_shift;
    end
 end


//  always @(posedge sys_clk or negedge sys_rst_n) begin
//     if(!sys_rst_n) begin

//     end else if()begin

//     end else if()begin

//     end else if()begin

//     end 
//  end

// data_shift :在偶数周期校准，奇数周期左移
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        data_shift <=64'd0;
    end else if(cnt_shift == 5'd0)begin
        data_shift <= {32'd0,data};
    end else if((cnt_shift <=26)&&(shift_flag ==0'd0))begin
        data_shift [27:24] <= (data_shift [27:24]>4)?(data_shift [27:24]+2'd3):data_shift [27:24];
        data_shift [31:28] <= (data_shift [27:24]>4)?(data_shift [27:24]+2'd3):data_shift [31:28];
        data_shift [35:32] <= (data_shift [27:24]>4)?(data_shift [27:24]+2'd3):data_shift [35:32];
        data_shift [39:36] <= (data_shift [27:24]>4)?(data_shift [27:24]+2'd3):data_shift [39:36];
        data_shift [43:40] <= (data_shift [27:24]>4)?(data_shift [27:24]+2'd3):data_shift [43:40];
        data_shift [47:44] <= (data_shift [27:24]>4)?(data_shift [27:24]+2'd3):data_shift [47:44];
        data_shift [51:48] <= (data_shift [27:24]>4)?(data_shift [27:24]+2'd3):data_shift [51:48];
        data_shift [55:52] <= (data_shift [27:24]>4)?(data_shift [27:24]+2'd3):data_shift [55:52];
        data_shift [59:56] <= (data_shift [27:24]>4)?(data_shift [27:24]+2'd3):data_shift [59:56];
        data_shift [63:60] <= (data_shift [27:24]>4)?(data_shift [27:24]+2'd3):data_shift [63:60];
    end else if((cnt_shift <=26) &&(shift_flag))begin
        data_shift <= data_shift <<1;
    end else begin
        data_shift <= data_shift;
    end
 end



//shift_flag 控制奇偶周期                     // 注释描述没问题，确实通过翻转 shift_flag 区分两个周期
 always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        shift_flag <= 1'd0;                  
    end else begin
        shift_flag <= ~shift_flag;
    end 
 end
// 迭代后 所存BCD输出
 always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        unit <= 4'd0;// bcd 个位
        ten<= 4'd0;// bcd 十位
        hun<= 4'd0;// bcd 百位
        tho<= 4'd0;// bcd 千位
        t_tho<= 4'd0;// bcd 万位
        h_hun<= 4'd0;// bcd 十万位
        mil<= 4'd0;// bcd 百万位
        t_mil<= 4'd0;// bcd千万位
    end else if(cnt_shift == 5'd27)begin
        unit    <=  data_shift [27:24];// bcd 个位
        ten     <=  data_shift [31:28];/// bcd 十位
        hun     <=  data_shift [35:32];/// bcd 百位
        tho     <=  data_shift [39:36];/// bcd 千位
        t_tho   <=  data_shift [43:40];/// bcd 万位
        h_hun   <=  data_shift [47:44];/// bcd 十万位
        mil     <=  data_shift [51:48];/// bcd 百万位
        t_mil   <=  data_shift [55:52];/// bcd千万位

 end

endmodule