module breath(
    input clk,       // 系统时钟输入
    input rst_n,     // 系统复位输入，低电平有效
    output reg led
);



parameter COUNT_MAX = 20'd10_000;     // 计数值
parameter COUNT_LEVEL_MAX = 20'd20_000; // 亮度变化的计数值

reg [19:0] count;       // 主计数器
reg [19:0] count_level;   // 控制亮度变化的计数器
reg [19:0] pwm_count;      // 用于生成PWM信号的计数器
reg [19:0] light_level;       // 当前亮度值

// 计时200us
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        count <= 20'd0;
    else if (count == COUNT_MAX - 20'd1)
        count <= 20'd0;
    else
        count <= count + 20'd1;
end

// 亮度计数值
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        count_level <= 20'd0;
    else if (count == 20'd0) begin
        if (count_level == COUNT_LEVEL_MAX - 20'd1)
            count_level <= 20'd0;
        else
            count_level <= count_level + 20'd1;
    end
end

// PWM信号的计数
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pwm_count <= 20'd0;
    else if (pwm_count == COUNT_MAX - 1)
        pwm_count <= 20'd0;
    else
        pwm_count <= pwm_count + 20'd1;
end

// 计算亮度值，实现呼吸灯效果
always @(*) begin
    if (count_level < COUNT_LEVEL_MAX/2)
        light_level <= count_level;                     // 递增亮度
    else
        light_level <= (COUNT_LEVEL_MAX - count_level); // 递减亮度
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        led <= 1'd1;
    else
        led <= (pwm_count < light_level) ? 1'b1 : 1'd0;       // 根据当前亮度值控制LED状态
end

endmodule