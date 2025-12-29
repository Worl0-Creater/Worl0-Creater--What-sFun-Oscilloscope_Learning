#ifndef PLATFORM
#define PLATFORM

#include "systick.h"
#include "gd32f30x.h"
#include "stdio.h"
#include "string.h"
#include "stdlib.h"
#include "stdbool.h"
#include "timer.h"
#include "spi.h"
#include "main.h"
#include "uart.h"
#include "iic.h"

typedef struct
{
	bool signed_flag;  //短按
	bool long_flag;    //长按
	bool double_flag;  //双击
	bool key_status;   //端口的电平状态
	uint8_t click_status;//按键按下是否稳定(消抖)
	int click_time;    //按键按下时长
	uint8_t double_status;//判断双击与否
	int double_time;    //按键之间间隔
}KEY;

typedef struct
{
	uint16_t dac_poff;//通道增益控制字
	uint16_t vertical_offset;//通道垂直基线偏移
	bool gain_sel;//衰减选择
}Calibration;


#define u32 uint32_t
#define u16 uint16_t
#define u8 uint8_t


extern uint8_t object; //当前控件
extern bool acdc;//耦合方式
extern bool ch;//当前通道

extern bool ch1_on;//通道1开关
extern bool ch2_on;//通道2开关
extern bool ch1_att;//通道1衰减切换
extern bool ch2_att;//通道2衰减切换
extern uint16_t ch1_gear;//通道1电压档位
extern uint16_t ch2_gear;//通道2电压档位
extern uint16_t ch1_offset;//通道1电压偏置
extern uint16_t ch2_offset;//通道2电压偏置

extern uint16_t time_gear;//水平档位
extern uint16_t time_offset;//水平偏置
extern uint16_t time_step;//抽取地址步进

extern uint8_t trig_level;//触发电平
extern bool trig_ch;//触发通道
extern uint8_t trig_mode;//触发模式
extern bool trig_edge;//触发边沿
extern bool stop;//暂停

extern uint8_t cursor_mode;//光标1开关
extern uint16_t x1;//光标x1位置
extern uint16_t x2;//光标x2位置
extern uint16_t y1;//光标y1位置
extern uint16_t y2;//光标y2位置

extern uint8_t dac_wave;//dac波形
extern uint8_t dac_att;//dac衰减
extern uint32_t dac_freq;//dac频率控制字
extern uint16_t number_ch;

extern bool adjust;//粗调细调

extern uint16_t reg[32];
extern KEY key[10];
extern Calibration ch1_cali[10];
extern Calibration ch2_cali[10];
extern Calibration ch1_gear_now;
extern Calibration ch2_gear_now;
extern uint8_t EC11_flag1,EC11_flag2;


void update_reg(uint8_t address);
void ctrl_init();
void update_ch_gear();



#endif
