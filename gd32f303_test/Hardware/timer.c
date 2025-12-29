#include "timer.h"
#include "spi.h"
#include "platform.h"

// 定时器初始化函数
void timer2_init(void) {
	rcu_periph_clock_enable(RCU_TIMER2);
    timer_parameter_struct timer_initpara;
    timer_struct_para_init(&timer_initpara);  // 初始化定时器结构体
    // 系统时钟为 120 MHz，APB1 时钟为 120 MHz，定时器时钟为 120 MHz
    timer_initpara.prescaler         = 119;  // 预分频值
    timer_initpara.alignedmode       = TIMER_COUNTER_EDGE;  // 边沿对齐模式
    timer_initpara.counterdirection  = TIMER_COUNTER_UP;    // 向上计数模式
    timer_initpara.period            = 5999;  // 自动重装载值
    timer_initpara.clockdivision     = TIMER_CKDIV_DIV1;    // 时钟分频
    timer_initpara.repetitioncounter = 0;                   // 重复计数器
    timer_init(TIMER2, &timer_initpara);


    timer_interrupt_enable(TIMER2, TIMER_INT_UP);
    nvic_irq_enable(TIMER2_IRQn, 2, 2); 
	timer_enable(TIMER2);
}




// 定时器中断服务程序
void TIMER2_IRQHandler(void) {
    static bool A1=1,B1=1,A1_r=1,B1_r=1;
	static bool A2=1,B2=1,A2_r=1,B2_r=1;
	if (RESET != timer_interrupt_flag_get(TIMER2, TIMER_INT_FLAG_UP)) {
        timer_interrupt_flag_clear(TIMER2, TIMER_INT_FLAG_UP);
		
		uint16_t key_state = SPI_ReadRegister(32);
		A1 = (key_state&0x0400)==0x0400;  B1 = (key_state&0x0800)==0x0800;
		A2 = (key_state&0x1000)==0x1000;  B2 = (key_state&0x2000)==0x2000;

		if(!A1 && A1_r && B1) EC11_flag1 = 2;//反传
		A1_r = A1;               
        if(!B1 && B1_r && A1) EC11_flag1 = 1;//正转
		B1_r = B1;  
		if(!A2 && A2_r && B2) EC11_flag2 = 2;
		A2_r = A2;               
        if(!B2 && B2_r && A2) EC11_flag2 = 1;
		B2_r = B2;  
		
		for(uint8_t i = 0;i < 10;i++)
		{
			key[i].key_status = (key_state >> i) & 0x1;
            //此处是判断按键是否稳定
			switch(key[i].click_status)
			{
				case 0://状态0：第一次按下
					if(key[i].key_status == RESET)
					{
						key[i].click_status = 1;//跳转状态1
					}
					break;
				case 1://状态1：电平已稳定
					if(key[i].key_status == RESET)
					{
						key[i].click_status = 2;
						key[i].click_time = 0; //计时器清零，准备调用
					}
					else
					{
						key[i].click_status = 0;
					}
					break;
				case 2:
					//若B1按下，则计时器一直增加
					if(key[i].key_status == RESET)
					{
						key[i].click_time ++;
					}
					//当端口电平状态为高电平时，且计数超过了某个值（根据题目而定）
					if(key[i].key_status == SET && key[i].click_time >= 150)
					{
						key[i].long_flag = 1;
						key[i].click_status = 0;//重置状态
					}
					//剩下情况就要区分短按和双击的区别
					else if(key[i].key_status == SET && key[i].click_time < 150)
					{
						switch(key[i].double_status)
						{
							case 0://状态0：第一次松开按键
								key[i].double_status = 1;
								key[i].double_time = 0;
								break;
							case 1://状态1：第二次松开按键
								key[i].double_flag = 1;
								key[i].double_status = 0;
								break;
						}
						key[i].click_status = 0;
					}
					break;
			}
			if(key[i].double_status == 1)//状态1：第一次松开后未按下按键
			{
				key[i].double_time ++;//若一直未按下第二次，则计数器一直计数
				if(key[i].double_time >= 35)
				{
					key[i].signed_flag = 1; //为短按
					key[i].double_status = 0;
				}
			}
		}
    }
}