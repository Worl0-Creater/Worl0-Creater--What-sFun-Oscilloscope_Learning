//------------------------------------------------------------------------------
// bcd_8421
//  - 双 dabble 算法：交替执行“>=5 加3”与左移，累计 27 次得到 BCD。
//  - 计数器/标志：cnt_shift 控制迭代次数，shift_flag 区分加3或移位阶段。
//------------------------------------------------------------------------------
module bcd_8421
(
    input   wire            sys_clk     ,   //系统时钟，频率100MHz
    input   wire            sys_rst_n   ,   //复位信号，低电平有效
    input   wire    [31:0]  data        ,   //输入需要转换的数据（最大99999999）

    output  reg     [3:0]   unit        ,   //个位BCD码
    output  reg     [3:0]   ten         ,   //十位BCD码
    output  reg     [3:0]   hun         ,   //百位BCD码
    output  reg     [3:0]   tho         ,   //千位BCD码
    output  reg     [3:0]   t_tho       ,   //万位BCD码
    output  reg     [3:0]   h_hun       ,   //十万位BCD码
    output  reg     [3:0]   mil         ,   //百万位BCD码
    output  reg     [3:0]   t_mil           //千万位BCD码
);

//********************************************************************//
//******************** Parameter And Internal Signal *****************//
//********************************************************************//

//reg   define
reg     [4:0]   cnt_shift   ;   //移位判断计数器
reg     [63:0]  data_shift  ;   //移位判断数据寄存器，扩展到64位
reg             shift_flag  ;   //移位判断标志信号

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

//------------------------------------------------------------------------------
// cnt_shift：跟踪 27 次迭代
//------------------------------------------------------------------------------
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_shift   <=  5'd0;
    else    if((cnt_shift == 5'd27) && (shift_flag == 1'b1))
        cnt_shift   <=  5'd0;
    else    if(shift_flag == 1'b1)
        cnt_shift   <=  cnt_shift + 1'b1;
    else
        cnt_shift   <=  cnt_shift;

//------------------------------------------------------------------------------
// data_shift：在偶周期校正，在奇周期左移
//------------------------------------------------------------------------------
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        data_shift  <=  64'b0;
    else    if(cnt_shift == 5'd0)
        data_shift  <=  {32'b0, data}; // 初始化时，低位对齐输入数据
    else    if((cnt_shift <= 26) && (shift_flag == 1'b0))
        begin
            // 对每个BCD位进行调整（如果大于4，则加3）
            data_shift[27:24]   <=  (data_shift[27:24] > 4) ? (data_shift[27:24] + 2'd3) : (data_shift[27:24]);
            data_shift[31:28]   <=  (data_shift[31:28] > 4) ? (data_shift[31:28] + 2'd3) : (data_shift[31:28]);
            data_shift[35:32]   <=  (data_shift[35:32] > 4) ? (data_shift[35:32] + 2'd3) : (data_shift[35:32]);
            data_shift[39:36]   <=  (data_shift[39:36] > 4) ? (data_shift[39:36] + 2'd3) : (data_shift[39:36]);
            data_shift[43:40]   <=  (data_shift[43:40] > 4) ? (data_shift[43:40] + 2'd3) : (data_shift[43:40]);
            data_shift[47:44]   <=  (data_shift[47:44] > 4) ? (data_shift[47:44] + 2'd3) : (data_shift[47:44]);
            data_shift[51:48]   <=  (data_shift[51:48] > 4) ? (data_shift[51:48] + 2'd3) : (data_shift[51:48]);
            data_shift[55:52]   <=  (data_shift[55:52] > 4) ? (data_shift[55:52] + 2'd3) : (data_shift[55:52]);
            data_shift[59:56]   <=  (data_shift[59:56] > 4) ? (data_shift[59:56] + 2'd3) : (data_shift[59:56]);
            data_shift[63:60]   <=  (data_shift[63:60] > 4) ? (data_shift[63:60] + 2'd3) : (data_shift[63:60]);
        end
    else    if((cnt_shift <= 26) && (shift_flag == 1'b1))
        data_shift  <=  data_shift << 1; // 左移一位
    else
        data_shift  <=  data_shift;

//------------------------------------------------------------------------------
// shift_flag：交替触发“校正/移位”阶段
//------------------------------------------------------------------------------
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        shift_flag  <=  1'b0;
    else
        shift_flag  <=  ~shift_flag;

//------------------------------------------------------------------------------
// 迭代完成后锁存 BCD 输出
//------------------------------------------------------------------------------
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        begin
            unit    <=  4'b0;
            ten     <=  4'b0;
            hun     <=  4'b0;
            tho     <=  4'b0;
            t_tho   <=  4'b0;
            h_hun   <=  4'b0;
            mil     <=  4'b0;
            t_mil   <=  4'b0;
        end
    else    if(cnt_shift == 5'd27)
        begin
            unit    <=  data_shift[27:24];
            ten     <=  data_shift[31:28];
            hun     <=  data_shift[35:32];
            tho     <=  data_shift[39:36];
            t_tho   <=  data_shift[43:40];
            h_hun   <=  data_shift[47:44];
            mil     <=  data_shift[51:48];
            t_mil   <=  data_shift[55:52]; // 千万位赋值
        end

endmodule