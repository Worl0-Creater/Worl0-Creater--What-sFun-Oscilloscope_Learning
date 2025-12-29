
module LCD 
(
    input				clk,		
    input				rst_n,		
    
    output	reg			lcd_res,	//LCD液晶屏复位
    output	reg			lcd_dc,		//LCD数据指令控制
    output	reg	[15:0]	lcd_data,	//LCD数据信号
    output  reg         lcd_rd,     //LCD读信号
    output  reg         lcd_wr,     //LCD写信号
    output  reg         lcd_cs,

	input stop,
	input [13:0] trig_pos,
	output reg [13:0] ram_addr,
	output reg ram_en,
	input [7:0] ram_data_a,
	input [7:0] ram_data_b,

    output reg display_done,
	input display_en,

	input wire [7:0] trig_level,
	input wire [(12*8-1):0] dis_measure_freq_buff,
	input wire [(10*8-1):0] dis_ch_buff,
	input wire [(3*8-1):0] dis_trig_ch_buff,
	input wire [(4*8-1):0] dis_stop_buff,
	input wire [(2*8-1):0] dis_acdc_buff,
	input wire [(3*8-1):0] dis_trig_edge_buff,
	input wire [(6*8-1):0] dis_trig_mode_buff,
	input wire [(3*8-1):0] dis_trig_level_buff,

	input [15:0] step,
	input wire [(9*8-1):0] dis_time_gear_buff,
	input wire [(9*8-1):0] dis_time_offset_buff,

	input wire [(10*8-1):0] dis_ch1_gear_buff,
	input wire [(3*8-1):0] dis_ch1_offset_buff,
	input wire [(10*8-1):0] dis_ch2_gear_buff,
	input wire [(3*8-1):0] dis_ch2_offset_buff,

	input wire [(8*8-1):0] dis_dac_wave_buff,
	input wire [(10*8-1):0] dis_dac_freq_buff,
	input wire [(6*8-1):0] dis_dac_att_buff,

	input wire [(6*8-1):0] dis_y1_buff,
	input wire [(6*8-1):0] dis_y2_buff,
	input wire [(6*8-1):0] dis_dy_buff,
	input wire [(6*8-1):0] dis_x1_buff,
	input wire [(6*8-1):0] dis_x2_buff,
	input wire [(6*8-1):0] dis_dx_buff,
	input wire [1:0] cursor_mode,
    input wire [15:0] number_ch,

	input wire [15:0] object
);

// 跨时钟域同步信号
reg display_en_sync_1;  // 第一级同步寄存器
reg display_en_sync_2;  // 第二级同步寄存器
wire display_en_sync = display_en_sync_2;// 同步后的信号

// 同步器：两级触发器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        display_en_sync_1 <= 1'b0;
        display_en_sync_2 <= 1'b0;
    end else begin
        display_en_sync_1 <= display_en;  // 第一级同步
        display_en_sync_2 <= display_en_sync_1; // 第二级同步
    end
end


localparam RAM_DEPTH = 16384;//RAM容量(字节)

localparam INIT_DEPTH = 16'd64; //LCD初始化的命令及数据的数量

	
localparam YELLOW =	16'hffe0;	
localparam BLUE =  16'h07ff;
localparam WHITE = 16'hffff;
localparam BLACK = 16'h0000;
localparam ORANGE = 16'ha500;
localparam GREY = 16'h6b4d;

localparam IDLE	= 4'd0, MAIN = 4'd1, INIT = 4'd2, SCAN = 4'd3, WRITE = 4'd4, DELAY = 4'd5 ,CHAR = 4'd6 ,CLEAR = 4'd7, POINT = 4'd8;
localparam SCAN2 = 4'd9;
localparam LOW = 1'b0, HIGH = 1'b1;
localparam DEFAULT_DELAY = 32'd1;

localparam x_offset=0;//屏幕x开始偏移
localparam y_offset=0;//屏幕y开始偏移

reg [15:0] color_b;//背景颜色
reg [15:0] color_t;//画笔颜色
reg [15:0] color;//画一个点的颜色

wire [16:0] reg_init [63:0];//初始化序列rom

reg [127:0]	char_data;//字符数据寄存器
reg	[8*21-1:0] char;//字符串寄存器,最大21字符
reg	[7:0]	char_num;//显示字符个数计数器
wire [127:0] mem [127:0];//字符串数据缓存

reg	[15:0]	y_s,x_s,y_e,x_e;//坐标起始和终点
reg [15:0]  x,y;//当前坐标寄存器
	
reg [16:0] data_reg;	//17位待发送数据，最高位为指令/数据选择
reg [15:0] x_cnt, y_cnt;//记录画点数量
reg [7:0] cnt_main, cnt_init;//主循环、初始化计数器
reg [7:0] cnt_write, cnt_scan, cnt_point; //发送数据、画点计数器
reg [31:0] num_delay, cnt_delay; //延时计数器
reg [15:0] cnt_init_add;//初始化代码地址
reg [7:0] state = IDLE, state_back = IDLE, state_backback = IDLE;//LCD状态机

wire flagx = (x_cnt==200)||(x_cnt==0)||(x_cnt==400);
wire flagy = (y_cnt==0)||(y_cnt==127)||(y_cnt==255);//画横着的线和垂直标尺;
wire flagx1 = (x_cnt==50)||(x_cnt==100)||(x_cnt==150)||(x_cnt==250)||(x_cnt==300)||(x_cnt==350);
wire flagy1 = (y_cnt==31)||(y_cnt==63)||(y_cnt==95)||(y_cnt==159)||(y_cnt==191)||(y_cnt==223);
wire cor_flag=flagx||flagy;//画坐标轴
wire cor_flag1=flagx1||flagy1;

wire line_flag1 = (((y_cnt > prev_y1) && (y_cnt <= current_y1)) || ((y_cnt > current_y1) && (y_cnt <= prev_y1))) && (x_cnt<400) && (x_cnt>2);//将波形的点连起来
wire line_flag2 = (((y_cnt > prev_y2) && (y_cnt <= current_y2)) || ((y_cnt > current_y2) && (y_cnt <= prev_y2))) && (x_cnt<400) && (x_cnt>2);//将波形的点连起来

wire trig_flag = ((x_cnt>=1 && x_cnt<=5) && (y_cnt==trig_level)) || ((x_cnt>=1 && x_cnt<=4) && (y_cnt==trig_level+1 || y_cnt==trig_level-1)) || 
				 ((x_cnt>=1 && x_cnt<=3) && (y_cnt==trig_level+2 || y_cnt==trig_level-2)) || ((x_cnt>=1 && x_cnt<=2) && (y_cnt==trig_level+3 || y_cnt==trig_level-3)) || 
				 ((x_cnt==1) && (y_cnt==trig_level+4 || y_cnt==trig_level-4));

reg [7:0] ram_data_r1;//画波形用的寄存器
reg [7:0] ram_data_r2;//画波形用的寄存器


reg [7:0] prev_y1,prev_y2;         // 前一个点的 y 值
reg [7:0] current_y1,current_y2;   // 当前点的 y 值

reg [15:0] step_times_r;
reg [13:0] trig_pos_minus_step;
wire [13:0] ram_addr_plus_step = ram_addr + step;
wire [13:0] ram_addr_next      = ram_addr_plus_step & 14'h3FFF;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        step_times_r         <= 0;
        trig_pos_minus_step  <= 0;
    end else begin
        step_times_r         <= step * 201; // 或其他方式
        trig_pos_minus_step  <= (trig_pos > step_times_r) ? (trig_pos - step_times_r) : ({1'b1, trig_pos} - step_times_r);
    end
end

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		x_cnt <= 1'b0; y_cnt <= 1'b0;
		cnt_main <= 0; cnt_init <= 1'b0; cnt_scan <= 1'b0; cnt_write <= 1'b0;
		num_delay <= DEFAULT_DELAY; cnt_delay <= 1'b0; cnt_init_add <= 1'b0; cnt_point <= 1'b0;
		lcd_res<=1'b1; lcd_dc<=1'b1; lcd_cs<= 1'b1;
        lcd_wr<=1'b1; lcd_rd<=1'b1;
		lcd_data<=16'd0;
		state <= IDLE; state_back <= IDLE;
	end else begin
		case(state)
			IDLE:begin
					x_cnt <= 1'b0; y_cnt <= 1'b0;
					cnt_main <= 0; cnt_init <= 1'b0; cnt_write <= 1'b0;
					num_delay <= DEFAULT_DELAY; cnt_delay <= 1'b0; cnt_init_add <= 1'b0;
					state <= MAIN; state_back <= MAIN;
				end
			MAIN:begin
					case(cnt_main)	//MAIN状态
						8'd0: begin state<=INIT; cnt_main<=cnt_main+1; display_done<=0; end//初始化
						8'd1: begin y_s<=(y_offset+0);y_e<=(y_offset+320); x_s<=(x_offset+0);x_e<=(x_offset+480); color_b<=BLACK; state<=CLEAR; cnt_main<=cnt_main+1; display_done<=0; end	//清屏
						8'd2: begin y_s<=(y_offset+26); x_s<=(x_offset+402); char_num<=8; char<="X1 X2 dX"; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd3: begin y_s<=(y_offset+95); x_s<=(x_offset+402); char_num<=8; char<="Y1 Y2 dY"; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd4: begin y_s<=(y_offset+217); x_s<=(x_offset+402); char_num<=9; char<="TRI_LEVEL"; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd5: begin	cnt_main<=display_en_sync?(cnt_main+1):cnt_main; display_done<=0; end
						8'd6: begin color_b<=BLACK; state<=SCAN; cnt_main<=cnt_main+1; end// 预计算地址end
						8'd7: begin display_done<=1; y_s<=(y_offset+164); x_s<=(x_offset+402); char_num<=4; char<=dis_stop_buff; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd8: begin display_done<=0; y_s<=(y_offset+164); x_s<=(x_offset+450); char_num<=3; char<=dis_trig_ch_buff; color_t<=(object==0)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd9: begin y_s<=(y_offset+180); x_s<=(x_offset+402); char_num<=2; char<=dis_acdc_buff; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd10: begin y_s<=(y_offset+180); x_s<=(x_offset+426); char_num<=3; char<=dis_trig_edge_buff; color_t<=(object==1)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd11: begin y_s<=(y_offset+196); x_s<=(x_offset+402); char_num<=6; char<=dis_trig_mode_buff; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd12: begin y_s<=(y_offset+277); x_s<=(x_offset+210); char_num<=12; char<="100Mbps 16KB"; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd13: begin y_s<=(y_offset+293); x_s<=(x_offset+210); char_num<=12; char<=dis_measure_freq_buff; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd14: begin y_s<=(y_offset+5); x_s<=(x_offset+402); char_num<=10; char<=dis_ch_buff; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd15: begin y_s<=(y_offset+261); x_s<=(x_offset+210); char_num<=9; char<=dis_time_gear_buff; color_t<=(object==7)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd16: begin y_s<=(y_offset+261); x_s<=(x_offset+290); char_num<=9; char<=dis_time_offset_buff; color_t<=(object==8)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd17: begin y_s<=(y_offset+261); x_s<=(x_offset+4); char_num<=10; char<=dis_ch1_gear_buff; color_t<=(object==3)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd18: begin y_s<=(y_offset+261); x_s<=(x_offset+92); char_num<=3; char<=dis_ch1_offset_buff; color_t<=(object==4)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd19: begin y_s<=(y_offset+277); x_s<=(x_offset+4); char_num<=10; char<=dis_ch2_gear_buff; color_t<=(object==5)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd20: begin y_s<=(y_offset+277); x_s<=(x_offset+92); char_num<=3; char<=dis_ch2_offset_buff; color_t<=(object==6)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd21: begin y_s<=(y_offset+261); x_s<=(x_offset+390); char_num<=8; char<=dis_dac_wave_buff; color_t<=(object==9)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd22: begin y_s<=(y_offset+277); x_s<=(x_offset+390); char_num<=10; char<=dis_dac_freq_buff; color_t<=(object==10)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
                        8'd23: begin y_s<=(y_offset+293); x_s<=(x_offset+390); char_num<=10; char<={8'd19,8'd19,8'd19,8'd19,8'd19,8'd19,8'd19,8'd19,8'd19,8'd19}; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end                
                        8'd24: begin
                            y_s<=(y_offset+293);
                            case(number_ch)
                                0: begin x_s<=(x_offset+446); end
                                1: begin x_s<=(x_offset+438); end
                                2: begin x_s<=(x_offset+430); end
                                3: begin x_s<=(x_offset+422); end
                                4: begin x_s<=(x_offset+414); end
                                5: begin x_s<=(x_offset+406); end
                                6: begin x_s<=(x_offset+398); end
                                7: begin x_s<=(x_offset+390); end
                                default: begin x_s<=(x_offset+390); end
                            endcase
                            color_t<=ORANGE; char<=8'd18; char_num<=1; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; 
                        end 
						8'd25: begin y_s<=(y_offset+295); x_s<=(x_offset+390); char_num<=6; char<=dis_dac_att_buff; color_t<=(object==11)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd26: begin y_s<=(y_offset+233); x_s<=(x_offset+402); char_num<=3; char<=dis_trig_level_buff; color_t<=(object==2)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd27: begin y_s<=(y_offset+42); x_s<=(x_offset+402); char_num<=6; char<=dis_x1_buff; color_t<=(object==12)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd28: begin y_s<=(y_offset+58); x_s<=(x_offset+402); char_num<=6; char<=dis_x2_buff; color_t<=(object==13)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd29: begin y_s<=(y_offset+74); x_s<=(x_offset+402); char_num<=6; char<=dis_dx_buff; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd30: begin y_s<=(y_offset+111); x_s<=(x_offset+402); char_num<=6; char<=dis_y1_buff; color_t<=(object==14)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd31: begin y_s<=(y_offset+127); x_s<=(x_offset+402); char_num<=6; char<=dis_y2_buff; color_t<=(object==15)?ORANGE:WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd32: begin y_s<=(y_offset+143); x_s<=(x_offset+402); char_num<=6; char<=dis_dy_buff; color_t<=WHITE; color_b<=BLACK; state<=CHAR; cnt_main<=cnt_main+1; end
						8'd33: begin cnt_main<=5; end
						default: state <= IDLE;
					endcase
				end
			INIT:begin	//初始化状态
					if(cnt_init == 3'd4) begin
						if(cnt_init_add == INIT_DEPTH) cnt_init <= 0;
						else    cnt_init <= cnt_init;
					end 
                    else 
                        cnt_init <= cnt_init + 1'b1;
					case(cnt_init)
						3'd0:	lcd_res <= 1'b0;	//复位有效
						3'd1:	begin num_delay <= 32'd10000000; state <= DELAY; state_back <= INIT; end	//延时
						3'd2:	lcd_res <= 1'b1;	//复位恢复
						3'd3:	begin num_delay <= 32'd10000000; state <= DELAY; state_back <= INIT; end	//延时
						3'd4:	if(cnt_init_add==INIT_DEPTH) begin //当64条指令及数据发出后，配置完成
									cnt_init_add <= 16'd0;	
									state <= MAIN;
								end else begin
									cnt_init_add <= cnt_init_add + 16'd1;
									data_reg <= reg_init[cnt_init_add];	
									if(cnt_init_add==16'd0)  num_delay <= 32'd10000000; //第1条指令需要较长延时
                                    else if(cnt_init_add==16'd62)  num_delay <= 32'd10000000; //第63条指令需要较长延时
									else    num_delay <= DEFAULT_DELAY;
									state <= WRITE; state_back <= INIT;
								end
						default: state <= IDLE;
					endcase
				end
			CLEAR:begin	//刷屏状态，从RAM中读取数据刷屏
					case(cnt_scan)
						8'd0:	begin data_reg <= {1'b0,8'h0,8'h2a};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= CLEAR;cnt_scan<=cnt_scan+1;end
						8'd1:	begin data_reg <= {1'b1,8'h0,x_s[15:8]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= CLEAR;cnt_scan<=cnt_scan+1;end
						8'd2:	begin data_reg <= {1'b1,8'h0,x_s[7:0]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= CLEAR;cnt_scan<=cnt_scan+1;end
						8'd3:	begin data_reg <= {1'b1,8'h0,x_e[15:8]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= CLEAR;cnt_scan<=cnt_scan+1;end
						8'd4:	begin data_reg <= {1'b1,8'h0,x_e[7:0]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= CLEAR;cnt_scan<=cnt_scan+1;end
						8'd5:	begin data_reg <= {1'b0,8'h0,8'h2b};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= CLEAR;cnt_scan<=cnt_scan+1;end
						8'd6:	begin data_reg <= {1'b1,8'h0,y_s[15:8]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= CLEAR;cnt_scan<=cnt_scan+1;end
						8'd7:	begin data_reg <= {1'b1,8'h0,y_s[7:0]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= CLEAR;cnt_scan<=cnt_scan+1;end
						8'd8:	begin data_reg <= {1'b1,8'h0,y_e[15:8]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= CLEAR;cnt_scan<=cnt_scan+1;end
						8'd9:	begin data_reg <= {1'b1,8'h0,y_e[7:0]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= CLEAR;cnt_scan<=cnt_scan+1;end
						8'd10:	begin data_reg <= {1'b0,8'h0,8'h2c};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= CLEAR;cnt_scan<=cnt_scan+1;end
						8'd11:	begin 							
							if(x_cnt==480) begin
								x_cnt <= 16'd0;	
								if(y_cnt==320) begin  y_cnt <= 16'd0; cnt_scan <= cnt_scan + 1'b1; end	//如果是最后一行就跳出循环
								else begin  y_cnt <= y_cnt + 1'b1; cnt_scan <= 8'd11; end	
							end else begin
								data_reg <= {1'b1,color_b[15:0]}; x_cnt <= x_cnt + 1'b1;//根据相应bit的状态判定显示顶层色或背景色
								num_delay <= DEFAULT_DELAY;	//设定延时时间
								state <= WRITE;	//跳转至WRITE状态
								state_back <= CLEAR;	//执行完WRITE及DELAY操作后返回原状态
							end
						end
						8'd12:	begin cnt_scan <= 1'b0; state <= MAIN; end
						default: state <= IDLE;
					endcase
			end
            SCAN:begin
                case(cnt_scan)
                    5'd0: begin ram_addr<=trig_pos_minus_step;; cnt_scan <= cnt_scan + 1'b1; end // 使用预计算地址
                    5'd1: begin ram_en <= HIGH; cnt_scan <= cnt_scan + 1'b1;end	
                    5'd2: begin ram_addr<=ram_addr_next; cnt_scan <= cnt_scan + 1'b1; end	// RAM时钟使能
                    5'd3: begin 
                        ram_data_r1 <= (255-ram_data_a); 
                        ram_data_r2 <= (255-ram_data_b); 
                        cnt_scan <= cnt_scan + 1'b1;
                    end
                    5'd4: begin 							
                        if(y_cnt == 256) begin	
                            y_cnt <= 0;
                            if(x_cnt==400) begin x_cnt<=0; cnt_scan<=cnt_scan+1'b1; end	// 如果是最后一行就跳出循环
                            else begin  
                                x_cnt <= x_cnt + 1'b1; 
                                cnt_scan <= 5'd2; // 提早返回到地址更新，形成流水线
                            end	
                        end else begin
                            if(ram_data_r1==y_cnt)begin
                                current_y1 <= ram_data_r1;
                                prev_y1 <= current_y1;
                            end
                            if(ram_data_r2==y_cnt)begin
                                current_y2 <= ram_data_r2;
                                prev_y2 <= current_y2;
                            end
                            y_cnt <= y_cnt + 1'b1;
                            y <= y_cnt; 
                            x <= ((ram_data_r1==y_cnt || ram_data_r2==y_cnt) && (x_cnt!=400))?x_cnt+1:x_cnt;
                            if(trig_flag) color <= ORANGE;
                            else if((ram_data_r1==y_cnt)||line_flag1) color <= YELLOW;
                            else if((ram_data_r2==y_cnt)||line_flag2) color <= BLUE;
                            else if(cor_flag) color <= WHITE;
                            else if(cor_flag1) color <= GREY;
                            else color <= color_b;
                                state <= POINT;	// 跳转至WRITE状态
                                state_backback <= SCAN;	// 执行完WRITE及DELAY操作后返回SCAN状态
                            end
                        end
                    5'd5: begin cnt_scan <= 0; state <= MAIN; ram_en <= LOW; end
                    default: state <= IDLE;
                endcase
            end
            CHAR: begin  // 字符显示状态
                case(cnt_scan)
                    5'd0: begin char_num <= char_num - 1'b1;  cnt_scan <= cnt_scan + 1; end
                    5'd1: begin char_data <= mem[char[(char_num*8)+:8]];   cnt_scan <= cnt_scan + 1; end
                    5'd2: begin  // 逐像素绘制
                        if(x_cnt == 128) begin
                            x_cnt <= 16'd0;
                            if(char_num == 0) begin
                                cnt_scan <= cnt_scan + 1;  
                            end else begin
                                cnt_scan <= 5'd0; 
                                x_s <= x_s + 8;
                            end
                        end else begin
                            x <= x_s + (x_cnt & 3'b111); 
                            y <= y_s + (x_cnt >>> 3);  
                            color <= char_data[127-x_cnt] ? color_t : color_b; 
                            state <= POINT; 
                            state_backback <= CHAR; 
                            x_cnt <= x_cnt + 1'b1;
                        end
                   end
                   5'd3: begin  cnt_scan <= 1'b0; state <= MAIN; end
                   default: state <= IDLE;
                endcase
            end
            POINT:begin //画一个点
               case(cnt_point)
                    5'd0:	begin data_reg <= {1'b0,8'h0,8'h2a};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1;end
                    5'd1:	begin data_reg <= {1'b1,8'h0,x[15:8]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1;end
					5'd2:	begin data_reg <= {1'b1,8'h0,x[7:0]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1;end
					5'd3:	begin data_reg <= {1'b1,8'h0,x[15:8]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1;end
					5'd4:	begin data_reg <= {1'b1,8'h0,x[7:0]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1;end
					5'd5:	begin data_reg <= {1'b0,8'h0,8'h2b};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1;end
					5'd6:	begin data_reg <= {1'b1,8'h0,y[15:8]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1;end
					5'd7:	begin data_reg <= {1'b1,8'h0,y[7:0]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1;end
					5'd8:	begin data_reg <= {1'b1,8'h0,y[15:8]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1;end
					5'd9:	begin data_reg <= {1'b1,8'h0,y[7:0]};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1;end
					5'd10:	begin data_reg <= {1'b0,8'h0,8'h2c};num_delay <= DEFAULT_DELAY;state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1;end
					5'd11:	begin data_reg <= {1'b1,color}; num_delay <= DEFAULT_DELAY; state <= WRITE; state_back <= POINT;cnt_point<=cnt_point+1; end
                    5'd12:  begin cnt_point <= 0; state = state_backback; end
					default: state <= IDLE;
				endcase
            end
			WRITE:begin	//WRITE状态，将数据按照8080时序发送给屏幕
					if(cnt_write == 8'd5) cnt_write <= 1'b0;
					else cnt_write <= cnt_write + 1'b1;
					case(cnt_write)
						8'd0:	begin lcd_dc <= data_reg[16]; lcd_rd <= HIGH; lcd_cs <= LOW; end	//17位数据最高位为命令数据控制位
						8'd1:	begin lcd_data <= data_reg[15:0]; end	//先发高位数据
						8'd2:	begin lcd_wr <= LOW;  end	
						8'd3:	begin lcd_wr <= HIGH; end
                        8'd4:	begin lcd_cs <= HIGH; end
                        8'd5:	begin state <= DELAY; end
						default: state <= IDLE;
					endcase
			end
			DELAY:begin	//延时状态
					if(cnt_delay == num_delay) begin
						cnt_delay <= 32'd0;
						state <= state_back; 
					end else cnt_delay <= cnt_delay + 1'b1;
				end
			default:state <= IDLE;
		endcase
	end
end




assign     reg_init[ 0] = {1'b0,8'h0, 8'h11}; // Sleep Out
assign     reg_init[ 1] = {1'b0,8'h0, 8'hF0}; 
assign     reg_init[ 2] = {1'b1,8'h0, 8'hC3}; 
assign     reg_init[ 3] = {1'b0,8'h0, 8'hF0}; 
assign     reg_init[ 4] = {1'b1,8'h0, 8'h96};   
assign     reg_init[ 5] = {1'b0,8'h0, 8'h36}; 
assign     reg_init[ 6] = {1'b1,8'h0, 8'h28}; //RBG  屏幕方向  刷新方向
assign     reg_init[ 7] = {1'b0,8'h0, 8'h3A}; 
assign     reg_init[ 8] = {1'b1,8'h0, 8'h55}; 
assign     reg_init[ 9] = {1'b0,8'h0, 8'hB4}; 
assign     reg_init[10] = {1'b1,8'h0, 8'h01}; 
assign     reg_init[11] = {1'b0,8'h0, 8'hB7}; 
assign     reg_init[12] = {1'b1,8'h0, 8'hC6}; 
assign     reg_init[13] = {1'b0,8'h0, 8'hE8}; 
assign     reg_init[14] = {1'b1,8'h0, 8'h40}; 
assign     reg_init[15] = {1'b1,8'h0, 8'h8A}; 
assign     reg_init[16] = {1'b1,8'h0, 8'h00}; 
assign     reg_init[17] = {1'b1,8'h0, 8'h00}; 
assign     reg_init[18] = {1'b1,8'h0, 8'h29}; 
assign     reg_init[19] = {1'b1,8'h0, 8'h19}; 
assign     reg_init[20] = {1'b1,8'h0, 8'hA5}; 
assign     reg_init[21] = {1'b1,8'h0, 8'h33}; 
assign     reg_init[22] = {1'b0,8'h0, 8'hC1}; 
assign     reg_init[23] = {1'b1,8'h0, 8'h06}; 
assign     reg_init[24] = {1'b0,8'h0, 8'hC2}; 
assign     reg_init[25] = {1'b1,8'h0, 8'hA7}; 
assign     reg_init[26] = {1'b0,8'h0, 8'hC5}; 
assign     reg_init[27] = {1'b1,8'h0, 8'h18}; 
assign     reg_init[28] = {1'b0,8'h0, 8'hE0}; // Positive Voltage Gamma Control
assign     reg_init[29] = {1'b1,8'h0, 8'hF0}; 
assign     reg_init[30] = {1'b1,8'h0, 8'h09}; 
assign     reg_init[31] = {1'b1,8'h0, 8'h0B}; 
assign     reg_init[32] = {1'b1,8'h0, 8'h06}; 
assign     reg_init[33] = {1'b1,8'h0, 8'h04}; 
assign     reg_init[34] = {1'b1,8'h0, 8'h15}; 
assign     reg_init[35] = {1'b1,8'h0, 8'h2F}; 
assign     reg_init[36] = {1'b1,8'h0, 8'h54}; 
assign     reg_init[37] = {1'b1,8'h0, 8'h42}; 
assign     reg_init[38] = {1'b1,8'h0, 8'h3C}; 
assign     reg_init[39] = {1'b1,8'h0, 8'h17}; 
assign     reg_init[40] = {1'b1,8'h0, 8'h14}; 
assign     reg_init[41] = {1'b1,8'h0, 8'h18}; 
assign     reg_init[42] = {1'b1,8'h0, 8'h1B}; 
assign     reg_init[43] = {1'b0,8'h0, 8'hE1}; // Negative Voltage Gamma Control
assign     reg_init[44] = {1'b1,8'h0, 8'hF0}; 
assign     reg_init[45] = {1'b1,8'h0, 8'h09}; 
assign     reg_init[46] = {1'b1,8'h0, 8'h0B}; 
assign     reg_init[47] = {1'b1,8'h0, 8'h06}; 
assign     reg_init[48] = {1'b1,8'h0, 8'h04}; 
assign     reg_init[49] = {1'b1,8'h0, 8'h03}; 
assign     reg_init[50] = {1'b1,8'h0, 8'h2D}; 
assign     reg_init[51] = {1'b1,8'h0, 8'h43}; 
assign     reg_init[52] = {1'b1,8'h0, 8'h42}; 
assign     reg_init[53] = {1'b1,8'h0, 8'h3B}; 
assign     reg_init[54] = {1'b1,8'h0, 8'h16}; 
assign     reg_init[55] = {1'b1,8'h0, 8'h14}; 
assign     reg_init[56] = {1'b1,8'h0, 8'h17}; 
assign     reg_init[57] = {1'b1,8'h0, 8'h1B}; 
assign     reg_init[58] = {1'b0,8'h0, 8'hF0}; 
assign     reg_init[59] = {1'b1,8'h0, 8'h3C}; 
assign     reg_init[60] = {1'b0,8'h0, 8'hF0}; 
assign     reg_init[61] = {1'b1,8'h0, 8'h69}; 
assign     reg_init[62] = {1'b0,8'h0, 8'h21}; 
assign     reg_init[63] = {1'b0,8'h0, 8'h29}; // Display On
   

assign mem[0  ]={8'h00,8'h00,8'h00,8'h18,8'h24,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h24,8'h18,8'h00,8'h00};//"0",48
assign mem[1  ]={8'h00,8'h00,8'h00,8'h08,8'h38,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h3E,8'h00,8'h00};//"1",49
assign mem[2  ]={8'h00,8'h00,8'h00,8'h3C,8'h42,8'h42,8'h42,8'h02,8'h04,8'h08,8'h10,8'h20,8'h42,8'h7E,8'h00,8'h00};//"2",50
assign mem[3  ]={8'h00,8'h00,8'h00,8'h3C,8'h42,8'h42,8'h02,8'h04,8'h18,8'h04,8'h02,8'h42,8'h42,8'h3C,8'h00,8'h00};//"3",51
assign mem[4  ]={8'h00,8'h00,8'h00,8'h04,8'h0C,8'h0C,8'h14,8'h24,8'h24,8'h44,8'h7F,8'h04,8'h04,8'h1F,8'h00,8'h00};//"4",52
assign mem[5  ]={8'h00,8'h00,8'h00,8'h7E,8'h40,8'h40,8'h40,8'h78,8'h44,8'h02,8'h02,8'h42,8'h44,8'h38,8'h00,8'h00};//"5",53
assign mem[6  ]={8'h00,8'h00,8'h00,8'h18,8'h24,8'h40,8'h40,8'h5C,8'h62,8'h42,8'h42,8'h42,8'h22,8'h1C,8'h00,8'h00};//"6",54
assign mem[7  ]={8'h00,8'h00,8'h00,8'h7E,8'h42,8'h04,8'h04,8'h08,8'h08,8'h10,8'h10,8'h10,8'h10,8'h10,8'h00,8'h00};//"7",55
assign mem[8  ]={8'h00,8'h00,8'h00,8'h3C,8'h42,8'h42,8'h42,8'h24,8'h18,8'h24,8'h42,8'h42,8'h42,8'h3C,8'h00,8'h00};//"8",56
assign mem[9  ]={8'h00,8'h00,8'h00,8'h38,8'h44,8'h42,8'h42,8'h42,8'h46,8'h3A,8'h02,8'h02,8'h24,8'h18,8'h00,8'h00};//"9",57
assign mem[10 ]={8'h00,8'h00,8'h00,8'h10,8'h10,8'h18,8'h28,8'h28,8'h24,8'h3C,8'h44,8'h42,8'h42,8'hE7,8'h00,8'h00};//"A",65
assign mem[11 ]={8'h00,8'h00,8'h00,8'hF8,8'h44,8'h44,8'h44,8'h78,8'h44,8'h42,8'h42,8'h42,8'h44,8'hF8,8'h00,8'h00};//"B",66
assign mem[12 ]={8'h00,8'h00,8'h00,8'h3E,8'h42,8'h42,8'h80,8'h80,8'h80,8'h80,8'h80,8'h42,8'h44,8'h38,8'h00,8'h00};//"C",67
assign mem[13 ]={8'h00,8'h00,8'h00,8'hF8,8'h44,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h44,8'hF8,8'h00,8'h00};//"D",68
assign mem[14 ]={8'h00,8'h00,8'h00,8'hFC,8'h42,8'h48,8'h48,8'h78,8'h48,8'h48,8'h40,8'h42,8'h42,8'hFC,8'h00,8'h00};//"E",69
assign mem[15 ]={8'h00,8'h00,8'h00,8'hFC,8'h42,8'h48,8'h48,8'h78,8'h48,8'h48,8'h40,8'h40,8'h40,8'hE0,8'h00,8'h00};//"F",70

assign mem[16 ]={8'h00,8'h3C,8'h44,8'h42,8'h92,8'h92,8'h91,8'h91,8'h91,8'h91,8'h91,8'h92,8'h82,8'h42,8'h24,8'h18};//①
assign mem[17 ]={8'h00,8'h3C,8'h44,8'h5A,8'hAA,8'hAA,8'h89,8'h89,8'h89,8'h89,8'h91,8'h92,8'h9E,8'h62,8'h24,8'h18};//②
assign mem[18 ]={8'hff,8'hff,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};//line
assign mem[19 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};//null

assign mem[32 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};//" ",32
assign mem[33 ]={8'h00,8'h00,8'h00,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h00,8'h00,8'h10,8'h10,8'h00,8'h00};//"!",33
assign mem[34 ]={8'h00,8'h12,8'h24,8'h24,8'h48,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};//""",34
assign mem[35 ]={8'h00,8'h00,8'h00,8'h12,8'h12,8'h12,8'h7E,8'h24,8'h24,8'h24,8'h7E,8'h24,8'h24,8'h24,8'h00,8'h00};//"#",35
assign mem[36 ]={8'h00,8'h00,8'h08,8'h3C,8'h4A,8'h4A,8'h48,8'h38,8'h0C,8'h0A,8'h0A,8'h4A,8'h4A,8'h3C,8'h08,8'h08};//"$",36
assign mem[37 ]={8'h00,8'h00,8'h00,8'h44,8'hA4,8'hA8,8'hA8,8'hB0,8'h54,8'h1A,8'h2A,8'h2A,8'h4A,8'h44,8'h00,8'h00};//"%",37
assign mem[38 ]={8'h00,8'h00,8'h00,8'h30,8'h48,8'h48,8'h48,8'h50,8'h6E,8'hA4,8'h94,8'h98,8'h89,8'h76,8'h00,8'h00};//"&",38
assign mem[39 ]={8'h00,8'h60,8'h20,8'h20,8'h40,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};//"'",39
assign mem[40 ]={8'h00,8'h02,8'h04,8'h08,8'h08,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h08,8'h08,8'h04,8'h02,8'h00};//"(",40
assign mem[41 ]={8'h00,8'h40,8'h20,8'h10,8'h10,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h10,8'h10,8'h20,8'h40,8'h00};//")",41
assign mem[42 ]={8'h00,8'h00,8'h00,8'h00,8'h10,8'h10,8'hD6,8'h38,8'h38,8'hD6,8'h10,8'h10,8'h00,8'h00,8'h00,8'h00};//"*",42
assign mem[43 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h08,8'h08,8'h08,8'h7F,8'h08,8'h08,8'h08,8'h00,8'h00,8'h00,8'h00};//"+",43
assign mem[44 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h60,8'h20,8'h20,8'h40};//",",44
assign mem[45 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h7E,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};//"-",45
assign mem[46 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h60,8'h60,8'h00,8'h00};//".",46
assign mem[47 ]={8'h00,8'h02,8'h04,8'h04,8'h04,8'h04,8'h08,8'h08,8'h10,8'h10,8'h10,8'h20,8'h20,8'h40,8'h40,8'h00};//"/",47
assign mem[48 ]={8'h00,8'h00,8'h00,8'h18,8'h24,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h24,8'h18,8'h00,8'h00};//"0",48
assign mem[49 ]={8'h00,8'h00,8'h00,8'h08,8'h38,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h3E,8'h00,8'h00};//"1",49
assign mem[50 ]={8'h00,8'h00,8'h00,8'h3C,8'h42,8'h42,8'h42,8'h02,8'h04,8'h08,8'h10,8'h20,8'h42,8'h7E,8'h00,8'h00};//"2",50
assign mem[51 ]={8'h00,8'h00,8'h00,8'h3C,8'h42,8'h42,8'h02,8'h04,8'h18,8'h04,8'h02,8'h42,8'h42,8'h3C,8'h00,8'h00};//"3",51
assign mem[52 ]={8'h00,8'h00,8'h00,8'h04,8'h0C,8'h0C,8'h14,8'h24,8'h24,8'h44,8'h7F,8'h04,8'h04,8'h1F,8'h00,8'h00};//"4",52
assign mem[53 ]={8'h00,8'h00,8'h00,8'h7E,8'h40,8'h40,8'h40,8'h78,8'h44,8'h02,8'h02,8'h42,8'h44,8'h38,8'h00,8'h00};//"5",53
assign mem[54 ]={8'h00,8'h00,8'h00,8'h18,8'h24,8'h40,8'h40,8'h5C,8'h62,8'h42,8'h42,8'h42,8'h22,8'h1C,8'h00,8'h00};//"6",54
assign mem[55 ]={8'h00,8'h00,8'h00,8'h7E,8'h42,8'h04,8'h04,8'h08,8'h08,8'h10,8'h10,8'h10,8'h10,8'h10,8'h00,8'h00};//"7",55
assign mem[56 ]={8'h00,8'h00,8'h00,8'h3C,8'h42,8'h42,8'h42,8'h24,8'h18,8'h24,8'h42,8'h42,8'h42,8'h3C,8'h00,8'h00};//"8",56
assign mem[57 ]={8'h00,8'h00,8'h00,8'h38,8'h44,8'h42,8'h42,8'h42,8'h46,8'h3A,8'h02,8'h02,8'h24,8'h18,8'h00,8'h00};//"9",57
assign mem[58 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h18,8'h18,8'h00,8'h00,8'h00,8'h00,8'h18,8'h18,8'h00,8'h00};//":",58
assign mem[59 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h10,8'h00,8'h00,8'h00,8'h00,8'h00,8'h10,8'h10,8'h10};//";",59
assign mem[60 ]={8'h00,8'h00,8'h00,8'h02,8'h04,8'h08,8'h10,8'h20,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h00,8'h00};//"<",60
assign mem[61 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h7E,8'h00,8'h00,8'h7E,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};//"=",61
assign mem[62 ]={8'h00,8'h00,8'h00,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h04,8'h08,8'h10,8'h20,8'h40,8'h00,8'h00};//">",62
assign mem[63 ]={8'h00,8'h00,8'h00,8'h3C,8'h42,8'h42,8'h62,8'h04,8'h08,8'h08,8'h08,8'h00,8'h18,8'h18,8'h00,8'h00};//"?",63
assign mem[64 ]={8'h00,8'h00,8'h00,8'h38,8'h44,8'h5A,8'hAA,8'hAA,8'hAA,8'hAA,8'hAA,8'h5C,8'h42,8'h3C,8'h00,8'h00};//"@",64
assign mem[65 ]={8'h00,8'h00,8'h00,8'h10,8'h10,8'h18,8'h28,8'h28,8'h24,8'h3C,8'h44,8'h42,8'h42,8'hE7,8'h00,8'h00};//"A",65
assign mem[66 ]={8'h00,8'h00,8'h00,8'hF8,8'h44,8'h44,8'h44,8'h78,8'h44,8'h42,8'h42,8'h42,8'h44,8'hF8,8'h00,8'h00};//"B",66
assign mem[67 ]={8'h00,8'h00,8'h00,8'h3E,8'h42,8'h42,8'h80,8'h80,8'h80,8'h80,8'h80,8'h42,8'h44,8'h38,8'h00,8'h00};//"C",67
assign mem[68 ]={8'h00,8'h00,8'h00,8'hF8,8'h44,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h44,8'hF8,8'h00,8'h00};//"D",68
assign mem[69 ]={8'h00,8'h00,8'h00,8'hFC,8'h42,8'h48,8'h48,8'h78,8'h48,8'h48,8'h40,8'h42,8'h42,8'hFC,8'h00,8'h00};//"E",69
assign mem[70 ]={8'h00,8'h00,8'h00,8'hFC,8'h42,8'h48,8'h48,8'h78,8'h48,8'h48,8'h40,8'h40,8'h40,8'hE0,8'h00,8'h00};//"F",70
assign mem[71 ]={8'h00,8'h00,8'h00,8'h3C,8'h44,8'h44,8'h80,8'h80,8'h80,8'h8E,8'h84,8'h44,8'h44,8'h38,8'h00,8'h00};//"G",71
assign mem[72 ]={8'h00,8'h00,8'h00,8'hE7,8'h42,8'h42,8'h42,8'h42,8'h7E,8'h42,8'h42,8'h42,8'h42,8'hE7,8'h00,8'h00};//"H",72
assign mem[73 ]={8'h00,8'h00,8'h00,8'h7C,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h7C,8'h00,8'h00};//"I",73
assign mem[74 ]={8'h00,8'h00,8'h00,8'h3E,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h88,8'hF0};//"J",74
assign mem[75 ]={8'h00,8'h00,8'h00,8'hEE,8'h44,8'h48,8'h50,8'h70,8'h50,8'h48,8'h48,8'h44,8'h44,8'hEE,8'h00,8'h00};//"K",75
assign mem[76 ]={8'h00,8'h00,8'h00,8'hE0,8'h40,8'h40,8'h40,8'h40,8'h40,8'h40,8'h40,8'h40,8'h42,8'hFE,8'h00,8'h00};//"L",76
assign mem[77 ]={8'h00,8'h00,8'h00,8'hEE,8'h6C,8'h6C,8'h6C,8'h6C,8'h6C,8'h54,8'h54,8'h54,8'h54,8'hD6,8'h00,8'h00};//"M",77
assign mem[78 ]={8'h00,8'h00,8'h00,8'hC7,8'h62,8'h62,8'h52,8'h52,8'h4A,8'h4A,8'h4A,8'h46,8'h46,8'hE2,8'h00,8'h00};//"N",78
assign mem[79 ]={8'h00,8'h00,8'h00,8'h38,8'h44,8'h82,8'h82,8'h82,8'h82,8'h82,8'h82,8'h82,8'h44,8'h38,8'h00,8'h00};//"O",79
assign mem[80 ]={8'h00,8'h00,8'h00,8'hFC,8'h42,8'h42,8'h42,8'h42,8'h7C,8'h40,8'h40,8'h40,8'h40,8'hE0,8'h00,8'h00};//"P",80
assign mem[81 ]={8'h00,8'h00,8'h00,8'h38,8'h44,8'h82,8'h82,8'h82,8'h82,8'h82,8'h82,8'hB2,8'h4C,8'h38,8'h06,8'h00};//"Q",81
assign mem[82 ]={8'h00,8'h00,8'h00,8'hFC,8'h42,8'h42,8'h42,8'h7C,8'h48,8'h48,8'h44,8'h44,8'h42,8'hE3,8'h00,8'h00};//"R",82
assign mem[83 ]={8'h00,8'h00,8'h00,8'h3E,8'h42,8'h42,8'h40,8'h20,8'h18,8'h04,8'h02,8'h42,8'h42,8'h7C,8'h00,8'h00};//"S",83
assign mem[84 ]={8'h00,8'h00,8'h00,8'hFE,8'h92,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h38,8'h00,8'h00};//"T",84
assign mem[85 ]={8'h00,8'h00,8'h00,8'hE7,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h42,8'h3C,8'h00,8'h00};//"U",85
assign mem[86 ]={8'h00,8'h00,8'h00,8'hE7,8'h42,8'h42,8'h44,8'h24,8'h24,8'h28,8'h28,8'h18,8'h10,8'h10,8'h00,8'h00};//"V",86
assign mem[87 ]={8'h00,8'h00,8'h00,8'hD6,8'h54,8'h54,8'h54,8'h54,8'h54,8'h6C,8'h28,8'h28,8'h28,8'h28,8'h00,8'h00};//"W",87
assign mem[88 ]={8'h00,8'h00,8'h00,8'hE7,8'h42,8'h24,8'h24,8'h18,8'h18,8'h18,8'h24,8'h24,8'h42,8'hE7,8'h00,8'h00};//"X",88
assign mem[89 ]={8'h00,8'h00,8'h00,8'hEE,8'h44,8'h44,8'h28,8'h28,8'h10,8'h10,8'h10,8'h10,8'h10,8'h38,8'h00,8'h00};//"Y",89
assign mem[90 ]={8'h00,8'h00,8'h00,8'h7E,8'h84,8'h04,8'h08,8'h08,8'h10,8'h20,8'h20,8'h42,8'h42,8'hFC,8'h00,8'h00};//"Z",90
assign mem[91 ]={8'h00,8'h1E,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h1E,8'h00};//"[",91
assign mem[92 ]={8'h00,8'h00,8'h40,8'h20,8'h20,8'h20,8'h10,8'h10,8'h10,8'h08,8'h08,8'h04,8'h04,8'h04,8'h02,8'h02};//"\\",92
assign mem[93 ]={8'h00,8'h78,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h78,8'h00};//"]",93
assign mem[94 ]={8'h00,8'h18,8'h24,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};//"^",94
assign mem[95 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hFF};//"_",95
assign mem[96 ]={8'h00,8'h60,8'h10,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};//"`",96
assign mem[97 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h38,8'h44,8'h0C,8'h34,8'h44,8'h4C,8'h36,8'h00,8'h00};//"a",97
assign mem[98 ]={8'h00,8'h00,8'h00,8'h00,8'hC0,8'h40,8'h40,8'h58,8'h64,8'h42,8'h42,8'h42,8'h64,8'h58,8'h00,8'h00};//"b",98
assign mem[99 ]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h1C,8'h22,8'h40,8'h40,8'h40,8'h22,8'h1C,8'h00,8'h00};//"c",99
assign mem[100]={8'h00,8'h00,8'h00,8'h00,8'h06,8'h02,8'h02,8'h3E,8'h42,8'h42,8'h42,8'h42,8'h46,8'h3B,8'h00,8'h00};//"d",100
assign mem[101]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h3C,8'h42,8'h42,8'h7E,8'h40,8'h42,8'h3C,8'h00,8'h00};//"e",101
assign mem[102]={8'h00,8'h00,8'h00,8'h00,8'h0C,8'h12,8'h10,8'h7C,8'h10,8'h10,8'h10,8'h10,8'h10,8'h7C,8'h00,8'h00};//"f",102
assign mem[103]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h3E,8'h44,8'h44,8'h38,8'h40,8'h3C,8'h42,8'h42,8'h3C};//"g",103
assign mem[104]={8'h00,8'h00,8'h00,8'h00,8'hC0,8'h40,8'h40,8'h5C,8'h62,8'h42,8'h42,8'h42,8'h42,8'hE7,8'h00,8'h00};//"h",104
assign mem[105]={8'h00,8'h00,8'h00,8'h30,8'h30,8'h00,8'h00,8'h70,8'h10,8'h10,8'h10,8'h10,8'h10,8'h7C,8'h00,8'h00};//"i",105
assign mem[106]={8'h00,8'h00,8'h00,8'h0C,8'h0C,8'h00,8'h00,8'h1C,8'h04,8'h04,8'h04,8'h04,8'h04,8'h04,8'h44,8'h78};//"j",106
assign mem[107]={8'h00,8'h00,8'h00,8'h00,8'hC0,8'h40,8'h40,8'h4E,8'h48,8'h50,8'h70,8'h48,8'h44,8'hEE,8'h00,8'h00};//"k",107
assign mem[108]={8'h00,8'h00,8'h00,8'h10,8'h70,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h10,8'h7C,8'h00,8'h00};//"l",108
assign mem[109]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hFE,8'h49,8'h49,8'h49,8'h49,8'h49,8'hED,8'h00,8'h00};//"m",109
assign mem[110]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hDC,8'h62,8'h42,8'h42,8'h42,8'h42,8'hE7,8'h00,8'h00};//"n",110
assign mem[111]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h3C,8'h42,8'h42,8'h42,8'h42,8'h42,8'h3C,8'h00,8'h00};//"o",111
assign mem[112]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hD8,8'h64,8'h42,8'h42,8'h42,8'h64,8'h58,8'h40,8'hE0};//"p",112
assign mem[113]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h1A,8'h26,8'h42,8'h42,8'h42,8'h26,8'h1A,8'h02,8'h07};//"q",113
assign mem[114]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hEE,8'h32,8'h20,8'h20,8'h20,8'h20,8'hF8,8'h00,8'h00};//"r",114
assign mem[115]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h3E,8'h42,8'h40,8'h3C,8'h02,8'h42,8'h7C,8'h00,8'h00};//"s",115
assign mem[116]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h10,8'h10,8'h7C,8'h10,8'h10,8'h10,8'h10,8'h12,8'h0C,8'h00,8'h00};//"t",116
assign mem[117]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hC6,8'h42,8'h42,8'h42,8'h42,8'h46,8'h3B,8'h00,8'h00};//"u",117
assign mem[118]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hEE,8'h44,8'h44,8'h28,8'h28,8'h10,8'h10,8'h00,8'h00};//"v",118
assign mem[119]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hDB,8'h89,8'h4A,8'h5A,8'h54,8'h24,8'h24,8'h00,8'h00};//"w",119
assign mem[120]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h76,8'h24,8'h18,8'h18,8'h18,8'h24,8'h6E,8'h00,8'h00};//"x",120
assign mem[121]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'hE7,8'h42,8'h24,8'h24,8'h18,8'h18,8'h10,8'h10,8'h60};//"y",121
assign mem[122]={8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h7E,8'h44,8'h08,8'h10,8'h10,8'h22,8'h7E,8'h00,8'h00};//"z",122
assign mem[123]={8'h00,8'h03,8'h04,8'h04,8'h04,8'h04,8'h04,8'h04,8'h08,8'h04,8'h04,8'h04,8'h04,8'h04,8'h03,8'h00};//"{",123
assign mem[124]={8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08,8'h08};//"|",124
assign mem[125]={8'h00,8'hC0,8'h20,8'h20,8'h20,8'h20,8'h20,8'h20,8'h10,8'h20,8'h20,8'h20,8'h20,8'h20,8'hC0,8'h00};//"}",125
assign mem[126]={8'h20,8'h5A,8'h04,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};//"~",126




 
endmodule
