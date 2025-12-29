#include "uart.h"



void usart_init(){
	rcu_periph_clock_enable(RCU_USART0);
	/* 配置GPIO复用功能 */
	gpio_init(BSP_USART_TX_PORT, GPIO_MODE_AF_PP, GPIO_OSPEED_MAX, BSP_USART_TX_PIN);
	gpio_init(BSP_USART_RX_PORT, GPIO_MODE_IN_FLOATING, GPIO_OSPEED_MAX, BSP_USART_RX_PIN);
	
	/* 串口配置*/    
	usart_deinit(BSP_USART); 							// 复位串口    
	usart_baudrate_set(BSP_USART, 115200); 				// 设置波特率    
	usart_parity_config(BSP_USART, USART_PM_NONE); 		// 没有校验位    
	usart_word_length_set(BSP_USART, USART_WL_8BIT); 	// 8位数据位    
	usart_stop_bit_set(BSP_USART, USART_STB_1BIT); 		// 1位停止位
	usart_receive_config(BSP_USART, USART_RECEIVE_ENABLE);		// 使能串口接收
    usart_transmit_config(BSP_USART, USART_TRANSMIT_ENABLE);	// 使能串口发送
	usart_interrupt_enable(BSP_USART, USART_INT_RBNE); // 读数据缓冲区非空中断
	usart_interrupt_enable(BSP_USART, USART_INT_IDLE); // DLE线检测中断
	nvic_irq_enable(BSP_USART_IRQ, 1, 0); // 配置中断优先级
	
	usart_enable(BSP_USART);	// 使能串口
	
#ifdef USART1_EN
	
	/* 配置GPIO复用功能 */
	gpio_init(USART1_TX_PORT, GPIO_MODE_AF_PP, GPIO_OSPEED_MAX, USART1_TX_PIN);
	gpio_init(USART1_RX_PORT, GPIO_MODE_IN_FLOATING, GPIO_OSPEED_MAX, USART1_RX_PIN);
	
	/* 串口配置*/    
	usart_deinit(USART1); 							// 复位串口    
	usart_baudrate_set(USART1,115200); 				// 设置波特率    
	usart_parity_config(USART1,USART_PM_NONE); 		// 没有校验位    
	usart_word_length_set(USART1,USART_WL_8BIT); 	// 8位数据位    
	usart_stop_bit_set(USART1,USART_STB_1BIT); 		// 1位停止位
	usart_receive_config(USART1, USART_RECEIVE_ENABLE);		// 使能串口接收
    usart_transmit_config(USART1, USART_TRANSMIT_ENABLE);	// 使能串口发送
	usart_interrupt_enable(USART1, USART_INT_RBNE); // 读数据缓冲区非空中断
	usart_interrupt_enable(USART1, USART_INT_IDLE); // DLE线检测中断
	nvic_irq_enable(USART1_IRQn, 1, 1); // 配置中断优先级
	
	usart_enable(USART1);	// 使能串口
#endif
}

void usart1_send_data(uint8_t byte)
{
    usart_data_transmit(USART1, (uint8_t)byte);  
    while(RESET == usart_flag_get(USART1, USART_FLAG_TBE)); // 等待发送数据缓冲区标志置位
}

uint8_t usart1_receive_data()
{
	return (uint8_t)usart_data_receive(USART1);
}

uint8_t  usart1_recv_buff[USART_RECEIVE_LENGTH]; // 接收缓冲区
uint16_t usart1_recv_length = 0; // 接收数据长度
uint8_t  usart1_recv_complete_flag = 0; // 接收完成标志位
void USART1_IRQHandler(void)
{
    if(usart_interrupt_flag_get(USART1,USART_INT_FLAG_RBNE) == SET){ // 接收缓冲区不为空
        usart1_recv_buff[usart1_recv_length++] = usart_data_receive(USART1);  // 把接收到的数据放到缓冲区中
    }
    if(usart_interrupt_flag_get(USART1,USART_INT_FLAG_IDLE) == SET){ // 检测到帧中断
        usart_data_receive(USART1); // 必须要读，读出来的值不能要
        usart1_recv_buff[usart1_recv_length] = '\0';
        usart1_recv_complete_flag = SET;// 接收完成
    }
}

void usart_send_data(uint8_t byte)
{
    usart_data_transmit(BSP_USART, (uint8_t)byte);  
    while(RESET == usart_flag_get(BSP_USART, USART_FLAG_TBE)); // 等待发送数据缓冲区标志置位
}

void usart1_send_String(uint8_t *ucstr)
{   
	while(ucstr && *ucstr){  // 地址为空或者值为空跳出     
		usart1_send_data(*ucstr++);    
    }
}

uint8_t usart_receive_data()
{
	return (uint8_t)usart_data_receive(BSP_USART);
}


uint8_t  usart0_recv_buff[USART_RECEIVE_LENGTH]; // 接收缓冲区
uint16_t usart0_recv_length = 0; // 接收数据长度
uint8_t  usart0_recv_complete_flag = 0; // 接收完成标志位
void BSP_USART_IRQHandler(void)
{
    if(usart_interrupt_flag_get(BSP_USART,USART_INT_FLAG_RBNE) == SET) // 接收缓冲区不为空
    {
         usart0_recv_buff[usart0_recv_length++] = usart_data_receive(BSP_USART);  // 把接收到的数据放到缓冲区中
    }
    if(usart_interrupt_flag_get(BSP_USART,USART_INT_FLAG_IDLE) == SET) // 检测到帧中断
    {
        usart_data_receive(BSP_USART); // 必须要读，读出来的值不能要
        usart0_recv_buff[usart0_recv_length] = '\0';
        usart0_recv_complete_flag = SET;// 接收完成
    }
}


void usart_send_String(uint8_t *ucstr)
{   
	while(ucstr && *ucstr){  // 地址为空或者值为空跳出     
		usart_send_data(*ucstr++);    
    }
}


/* retarget the C library printf function to the USART */
int fputc(int ch, FILE *f)
{
    usart_send_data(ch);
    return ch;
}
