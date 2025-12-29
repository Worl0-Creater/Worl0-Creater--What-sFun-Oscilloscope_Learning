//------------------------------------------------------------------------------
// data_handler
//  - AD9288 双通道数据流降采样、触发判定与缓存。
//  - 负责写入双端口 RAM、与 LCD 时钟域握手 display_en/done。
//  - 包含自动触发定时、波形测频、采集状态机。
//------------------------------------------------------------------------------
module data_handler(
    input clk,
	input clkb,
    input rst_n,
    input [7:0] ad_data_a,
    input [7:0] ad_data_b,

	input ch,//当前活跃通道
	input trig_ch,//触发通道选择
    input [15:0] rate_select,//时基抽样速率
    input [7:0] trig_level,//触发电平
    input trig_edge,  // 触发边沿选择 0为上升沿 1为下降沿
    input wire [1:0] trig_mode, //0自动 1标准 2单次
    input pause,
	output reg stop,

	output reg display_en,
	input display_done,

	output reg [13:0] trig_pos, //触发时ram地址
	output wire [31:0] measure_freq,

    input read_enable,
    output [7:0] ram_data_out_a,
    output [7:0] ram_data_out_b,
    input [14:0] ram_data_addr
);

/**************************降采样*****************************/

//****************************************************************************************//
//每格50个点	
//点间距	        10ns  20ns 40ns 100ns 200ns 
//采样率（HZ）   100M  50M  25M  10M   5M    2.5M  1M   500k  250k  100k 50k  25k  10k  5k   2.5k  1k    500   250   100
//降采样计数器   1     2    5    10    20    50    100  200   500   1k   2k   5k   10k  20k  50k   100k  200k  500k  1M
//****************************************************************************************//
reg [31:0] deci_rate;
reg [15:0] rate_select_prev; // 上一次的 rate_select 值
reg [15:0] rate_select_sync1, rate_select_sync2; // 同步后的 rate_select

// 同步 rate_select
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rate_select_sync1 <= 0;
        rate_select_sync2 <= 0;
    end else begin
        rate_select_sync1 <= rate_select;
        rate_select_sync2 <= rate_select_sync1;
    end
end

// 更新 deci_rate：根据时基选择映射分频比
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        deci_rate <= 32'd1; // 默认值为 1 分频
    end else begin
        case (rate_select_sync2)
            1:  deci_rate <= 32'd1;     // 1 分频
            2:  deci_rate <= 32'd1;     // 2 分频
            3:  deci_rate <= 32'd1;     // 5 分频
            4:  deci_rate <= 32'd1;    // 10 分频
            5:  deci_rate <= 32'd1;    // 20 分频
            6:  deci_rate <= 32'd1;    // 50 分频
            7:  deci_rate <= 32'd4;   // 100 分频
            8:  deci_rate <= 32'd5;   // 200 分频
            9:  deci_rate <= 32'd10;   // 500 分频
            10: deci_rate <= 32'd25;  // 1k 分频
            11: deci_rate <= 32'd50;  // 2k 分频
            12: deci_rate <= 32'd100;  // 5k 分频
            13: deci_rate <= 32'd250; // 10k 分频
            14: deci_rate <= 32'd500; // 20k 分频
            15: deci_rate <= 32'd1000; // 50k 分频
            16: deci_rate <= 32'd2500;// 100k 分频
            17: deci_rate <= 32'd5000;// 200k 分频
            18: deci_rate <= 32'd10000;// 500k 分频
            19: deci_rate <= 32'd25000;// 1M 分频
            20: deci_rate <= 32'd50000;// 2M 分频
            default: deci_rate <= 32'd1;// 默认值为 1 分频
        endcase
    end
end

// 记录上一次的 rate_select 值
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        rate_select_prev <= 5'd0;
    else
        rate_select_prev <= rate_select_sync2;
end

// 降采样计数器
reg [31:0] deci_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        deci_cnt <= 31'd0;
    else if (rate_select_sync2 != rate_select_prev) // 检测 rate_select 是否发生变化
        deci_cnt <= 31'd0; // 强制复位计数器
    else if (deci_cnt == deci_rate - 1)
        deci_cnt <= 31'd0;
    else
        deci_cnt <= deci_cnt + 1'b1;
end

// 降采样有效信号
reg deci_valid_r;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        deci_valid_r <= 1'b0;
    else if (rate_select_sync2 != rate_select_prev) // 检测 rate_select 是否发生变化
        deci_valid_r <= 1'b0; // 强制复位有效信号
    else if (deci_cnt == deci_rate - 1)
        deci_valid_r <= 1'b1;
    else
        deci_valid_r <= 1'b0;
end

wire deci_valid = (deci_rate == 1) ? 1 : deci_valid_r;





/****************************触发*******************************/
// 寄存 AD 数据，用于判断触发条件
reg [7:0] ad_data_r; 

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ad_data_r  <= 8'd0;
    end else if (deci_valid) begin
        ad_data_r  <= trig_ch ? ad_data_b : ad_data_a;
    end
end

wire trig_pulse = trig_edge ? ((ad_data_r >= trig_level) && ((trig_ch ? ad_data_b : ad_data_a) < trig_level))
						   : ((ad_data_r <= trig_level) && ((trig_ch ? ad_data_b : ad_data_a) > trig_level)) ;

reg trig_flag;  

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        trig_flag <= 1'b0;
    end else begin
        if (trig_pulse) begin
            trig_flag <= 1'b1;
        end else if (trig_flag) begin
            trig_flag <= 1'b0; 
        end
    end
end

reg [31:0] auto_cnt;//自动触发计时
reg auto_trig;//自动触发
always@(posedge clk)begin
	if(auto_trig || (auto_cnt==0))begin
		case(rate_select_sync2)
            default:auto_cnt<=28'd50000;
			8:auto_cnt<=28'd50000;//500us
			9:auto_cnt<=28'd100000;//1ms
            10:auto_cnt<=28'd900000;//9ms
            11:auto_cnt<=28'd1800000;//18ms
            12:auto_cnt<=28'd4000000;//40ms
            13:auto_cnt<=28'd8000000;//80ms
            14:auto_cnt<=28'd16000000;//160ms
            15:auto_cnt<=28'd40000000;//400ms
            16:auto_cnt<=28'd80000000;//800ms
            17:auto_cnt<=28'd160000000;//1600ms
		endcase
	end
	else 
        auto_cnt<=auto_cnt - 1;
	if( (auto_cnt<=10) && (trig_mode==0))//自动触发模式下
		auto_trig <= 1;
	else 
        auto_trig <= 0;
end
/***************************测量频率********************************/
wire [7:0] data2freq = ch?ad_data_b:ad_data_a;

freq_measure freq_measure_a (
    .clk(clk),   // 时钟信号
    .rst_n(rst_n),   // 异步复位信号，低电平有效
    .data_in(data2freq),   // 模拟输入信号（假设是10位）
    .trig_level(trig_level),   // 触发电平
    .freq(measure_freq)// 待检测时钟频率
);

//freq_measure freq_measure_b (
//    .clk(clk),   // 时钟信号
//    .rst_n(rst_n),   // 异步复位信号，低电平有效
//    .data_in(ad_data_b),   // 模拟输入信号（假设是10位）
//    .trig_level(trig_level),   // 触发电平
//    .freq(freq_b)// 待检测时钟频率
//);

//assign measure_freq = ch?freq_b:freq_a;

/***************************RAM********************************/
// 采集/写入状态机：
//  - 将当前选通道数据写入双口 RAM（write_data_a/write_data_b、write_addr、write_enable）。
//  - 通过 ad_cnt/count_delay 控制采样点数与写入节奏。
//  - 使用 state 实现多状态采集流程，trig_ok 标记触发满足，pause_reg/stop 实现暂停/停止控制。
//  - 采集完成后通过 display_en 与显示模块进行握手，由 display_done 返回。
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		state<=0;
	end
	else begin
		case(state)
			0:begin
				write_enable<=1;
				ad_cnt<=0;
				if(!stop) state<=4;
				else state<=state+1;
		  	end
			1:begin
				if(deci_valid) begin
					write_enable<=1;
					write_addr<=(write_addr+1'b1)&14'h3FFF;					
					write_data_a<=ad_data_a; write_data_b<=ad_data_b;
					ad_cnt<=ad_cnt+1;
					state<=(ad_cnt>=8191)?(state+1'b1):state;
				end
				else begin
					state<=state;
					ad_cnt<=ad_cnt;
					write_addr<=write_addr;
				end
		  	end		
	   		2:begin
				if(auto_trig||trig_flag)begin
					write_enable <= 1;
					write_addr <= (write_addr+1'b1)&14'h3FFF;
					trig_pos <= (write_addr+1'b1)&14'h3FFF;
					ad_cnt <= ad_cnt+1;
					write_data_a<=ad_data_a; write_data_b<=ad_data_b;
					state <= state+1;
					if(trig_mode==2) trig_ok<=1;
					else trig_ok<=0; end
				else begin
					state<=state;
					if(deci_valid) begin
						write_enable<=1;
						write_addr<=(write_addr+1'b1)&14'h3FFF;
						ad_cnt<=8191;
						write_data_a<=ad_data_a; write_data_b<=ad_data_b;
					end else begin
						state<=state;
						ad_cnt<=ad_cnt;
						write_addr<=write_addr;
					end
				end
			end
			3:begin
				if(ad_cnt>=RAM_DEPTH-1) begin
					state<=state+1;
					ad_cnt<=0;
					write_enable<=0;
					trig_ok<=0;
				end else begin
					if(deci_valid) begin
						write_enable<=1;
						write_addr<=(write_addr+1'b1)&14'h3FFF;
						ad_cnt<=ad_cnt+1;
						write_data_a<=ad_data_a; write_data_b<=ad_data_b;
					end else begin
						state<=state;
						ad_cnt<=ad_cnt;
						write_addr<=write_addr;
					end	
				end
		  	end
			4:begin
				display_en<=1;           // 请求 LCD 启动刷新
			 	state<=state+1;
			end
			5:begin
				if(display_done_sync) begin
					state<=state+1;
					display_en<=0;       // LCD 完成显示，撤销请求
				end else begin
					state<=state;
					display_en<=1;
				end
			end
			6:begin
				count_delay<=0;
				state<=state+1;
			end
			7:begin
				if(count_delay < 0)begin
				 	count_delay<=count_delay+1;
				 	state<=state;
				end else begin
					state<=0;
				end
			end
			default:state<=0;
		endcase	
	end
end


// 通道 A 的 RAM 实例化
Gowin_SDPB Gowin_SDPB_A (
    .dout(ram_data_out_a), 
    .clka(clk), 
    .cea(write_enable), 
    .reseta(!rst_n), 
    .clkb(clkb), 
    .ceb(read_enable), 
    .resetb(!rst_n), 
    .oce(1'b1), 
    .ada(write_addr), 
    .din(write_data_a), 
    .adb(ram_data_addr)
);

// 通道 B 的 RAM 实例化
Gowin_SDPB Gowin_SDPB_B (
    .dout(ram_data_out_b), 
    .clka(clk), 
    .cea(write_enable), 
    .reseta(!rst_n), 
    .clkb(clkb), 
    .ceb(read_enable), 
    .resetb(!rst_n), 
    .oce(1'b1), 
    .ada(write_addr), 
    .din(write_data_b), 
    .adb(ram_data_addr)
);


/************************** 跨时钟域同步 ***************************/
// display_done → data_handler 时钟域
reg display_done_sync_1, display_done_sync_2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        display_done_sync_1 <= 1'b0;
        display_done_sync_2 <= 1'b0;
    end else begin
        // 使用两级寄存器同步 display_done_a 和 display_done_b
        display_done_sync_1 <= display_done;
        display_done_sync_2 <= display_done_sync_1;
    end
end

wire display_done_sync = display_done_sync_2;


endmodule
