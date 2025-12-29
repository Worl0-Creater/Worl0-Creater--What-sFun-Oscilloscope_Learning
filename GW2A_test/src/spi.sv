module spi_slave (
    input clk,
    input rst_n,
    input SCK,
    input MOSI,
    input CS,
    input WR,
    output MISO,
    output reg [15:0] regs [31:0], // 32个16位寄存器
    input [13:0] key_in
);

reg [15:0] key_reg;

// 直接读取按键状态
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_reg <= 16'b1111111111111111;  // 复位时默认按键未按下
    end 
    else begin
        key_reg <= {2'b11,key_in};  // 直接将按键输入赋值给输出
    end
end



// 定义状态机
typedef enum reg [1:0] {IDLE, RECEIVE_ADDR, WRITE_DATA, SEND_DATA} state_t;
state_t current_state, next_state;

// 辅助寄存器
reg [7:0] address;      // 8位地址
reg [15:0] data_to_write; // 写入数据
reg [15:0] data_to_read;  // 读取数据
reg [4:0] bit_count;    // 位计数器（0~15）
reg [1:0] cs_reg;            // CS信号
reg [1:0] sck_reg;

always @(posedge clk or negedge rst_n)begin
	    if(!rst_n)begin
	        cs_reg <= 2'b00;
            sck_reg <= 2'b00;
	    end
	    else begin
	        cs_reg <= {cs_reg[0], CS}; 
            sck_reg <= {sck_reg[0], SCK}; 
	    end
end
	
wire cs_neg = cs_reg[1] & ~cs_reg[0];
wire sck_pos = ~sck_reg[1] & sck_reg[0];


// MISO驱动逻辑
assign MISO = (current_state == SEND_DATA) ? data_to_read[15 - bit_count] : 1'bz;

always@(posedge clk) begin
    if(!rst_n)begin
        current_state <= IDLE;
        bit_count <= 0;
        address <= 8'b0;
        data_to_write <= 16'b0;
        data_to_read <= 16'd0;
    end 
    else begin
        case (current_state)
            IDLE: begin
                // 检测CS下降沿
                if (cs_neg) begin 
                    current_state <= RECEIVE_ADDR;
                end
            end
            
            RECEIVE_ADDR: begin 
                    if (bit_count < 8) begin
                        if(sck_pos)begin
                            // 接收地址的每一位
                            address[7-bit_count] <= MOSI;
                            bit_count <= bit_count + 1;
                        end
                    end 
                    else begin
                        // 根据WR信号选择操作
                        if (WR) begin // WR高电平为写操作
                            current_state <= WRITE_DATA;
                            bit_count <= 0;
                        end 
                        else begin // WR低电平为读操作
                            current_state <= SEND_DATA;
                            if(address < 8'd16)  data_to_read <= regs[address[4:0]]; // 使用地址的低5位
                            else if(address == 8'd32) data_to_read <= key_reg;
                            bit_count <= 0;
                        end
                    end
            end
            
            WRITE_DATA: begin 
                if (bit_count < 16) begin 
                    if(sck_pos)begin
                        // 接收写入数据的每一位
                        bit_count <= bit_count + 1;
                        data_to_write[15-bit_count] <= MOSI;
                    end
                end 
                else begin
                    // 写入寄存器
                    regs[address[4:0]] <= data_to_write;
                    current_state <= IDLE;
                    bit_count <= 0;
                    address <= 8'd0;
                    data_to_write <= 16'd0;
                    data_to_read <= 16'd0;
                end
            end
            
            SEND_DATA: begin
                if (bit_count < 16) begin 
                    if(sck_pos)begin
                        // 发送数据的每一位
                        bit_count <= bit_count + 1;
                    end
                end 
                else begin
                    current_state <= IDLE;
                    bit_count <= 0;
                    address <= 8'd0;
                    data_to_write <= 16'd0;
                    data_to_read <= 16'd0;
                end
            end
        endcase
    end
end

endmodule