//------------------------------------------------------------------------------
// freq_measure
//  - 基于滞回比较器判定触发电平，统计单位闸门内的上升沿数量。
//  - gate_s/gate_a 构成软件闸门窗口，calc_flag 翻转时输出最新频率。
//------------------------------------------------------------------------------
module freq_measure (
    input clk,   
    input rst_n,   
    input [7:0] data_in,  
    input [7:0] trig_level,   // 触发电平
    output reg [31:0] freq           // 待检测时钟频率
);

//------------------------------------------------------------------------------
// 滞回比较 + 触发信号生成
//------------------------------------------------------------------------------
reg freq_trig;                      // 待测信号（不要综合成时钟）
wire clk_test = freq_trig;

// 滞回比较器模块
wire [7:0] trig_level_1 = trig_level + 15;
wire [7:0] trig_level_2 = trig_level - 15;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        freq_trig <= 1'b0;
    else if (data_in > trig_level_1)
        freq_trig <= 1'b1;
    else if (data_in < trig_level_2)
        freq_trig <= 1'b0;
end

//------------------------------------------------------------------------------
// 软件闸门计数与开窗控制
//------------------------------------------------------------------------------
// 参数定义
parameter CNT_GATE_S_MAX = 32'd149_999_999; // 软件闸门计数器最大值
parameter CNT_RISE_MAX = 32'd25_000_000;    // 软件闸门拉高计数值

// 内部信号定义
reg [31:0] cnt_gate_s;              // 软件闸门计数器
reg gate_s;                         // 软件闸门
reg gate_a;                         // 实际闸门
reg gate_a_stand;                   // 实际闸门打一拍(标准时钟下)
reg gate_a_test;                    // 实际闸门打一拍(待检测时钟下)
reg [31:0] cnt_clk_test;            // 待检测时钟周期计数器
reg [31:0] cnt_clk_test_reg;        // 实际闸门下待检测时钟周期数
reg calc_flag;                      // 待检测时钟频率计算标志信号
reg [31:0] freq_reg;                // 待检测时钟频率寄存
reg calc_flag_reg;                  // 待检测时钟频率输出标志信号

// 软件闸门计数器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cnt_gate_s <= 32'd0;
    else if (cnt_gate_s == CNT_GATE_S_MAX)
        cnt_gate_s <= 32'd0;
    else
        cnt_gate_s <= cnt_gate_s + 1'b1;
end

// 软件闸门
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        gate_s <= 1'b0;
    else if ((cnt_gate_s >= CNT_RISE_MAX) && (cnt_gate_s <= (CNT_GATE_S_MAX - CNT_RISE_MAX)))
        gate_s <= 1'b1;
    else
        gate_s <= 1'b0;
end

// 实际闸门（基于 clk 同步处理）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        gate_a <= 1'b0;
    else
        gate_a <= gate_s;
end

//------------------------------------------------------------------------------
// 待测信号上升沿计数 & 闸门同步
//------------------------------------------------------------------------------
reg freq_trig_dly;                  // 延迟一拍的 freq_trig
reg freq_trig_rise;                 // freq_trig 上升沿检测信号
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        freq_trig_dly <= 1'b0;
        freq_trig_rise <= 1'b0;
    end else begin
        freq_trig_dly <= freq_trig; // 打一拍延迟
        freq_trig_rise <= (~freq_trig_dly) && freq_trig; // 上升沿检测
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cnt_clk_test <= 32'd0;
    else if (gate_a == 1'b0)
        cnt_clk_test <= 32'd0;
    else if (freq_trig_rise)         // 在 freq_trig 上升沿计数
        cnt_clk_test <= cnt_clk_test + 1'b1;
end

// 实际闸门打一拍(标准时钟下)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        gate_a_stand <= 1'b0;
    else
        gate_a_stand <= gate_a;
end

// 实际闸门下降沿(标准时钟下)
wire gate_a_fall_s = (gate_a_stand == 1'b1) && (gate_a == 1'b0);

// 实际闸门打一拍(待检测时钟下)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        gate_a_test <= 1'b0;
    else
        gate_a_test <= gate_a;
end

// 实际闸门下降沿(待检测时钟下)
wire gate_a_fall_t = (gate_a_test == 1'b1) && (gate_a == 1'b0);

// 实际闸门下待检测时钟周期数
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cnt_clk_test_reg <= 32'd0;
    else if (gate_a_fall_t)
        cnt_clk_test_reg <= cnt_clk_test;
end

//------------------------------------------------------------------------------
// 频率寄存与输出
//------------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        calc_flag <= 1'b0;
    else if (cnt_gate_s == (CNT_GATE_S_MAX - 1'b1))
        calc_flag <= 1'b1;
    else
        calc_flag <= 1'b0;
end

// 待检测时钟信号时钟频率寄存
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        freq_reg <= 32'd0;
    else if (calc_flag)
        freq_reg <= cnt_clk_test_reg;
end

// 待检测时钟频率输出标志信号
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        calc_flag_reg <= 1'b0;
    else
        calc_flag_reg <= calc_flag;
end

// 待检测时钟信号时钟频率
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        freq <= 32'd0;
    else if (calc_flag_reg)
        freq <= freq_reg >> 2; // 根据实际需求调整分频系数
end

endmodule