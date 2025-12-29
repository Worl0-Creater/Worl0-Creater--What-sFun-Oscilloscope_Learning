#include "platform.h"

uint8_t object=0; //当前控件
bool acdc=0;//耦合方式
bool ch=0;//当前通道

bool ch1_on=1;//通道1开关
bool ch2_on=1;//通道2开关
bool ch1_att;//通道1衰减切换
bool ch2_att;//通道2衰减切换
uint16_t ch1_gear=7;//通道1电压档位
uint16_t ch2_gear=7;//通道2电压档位
uint16_t ch1_offset=512;//通道1电压偏置
uint16_t ch2_offset=512;//通道2电压偏置

uint16_t time_gear = 1;//水平档位
uint16_t time_offset = 0;//水平偏置
uint16_t time_step = 1;//抽取地址步进

uint8_t trig_level=128;//触发电平
bool trig_ch=0;//触发通道
uint8_t trig_mode=0;//触发模式
bool trig_edge=0;//触发边沿
bool stop = 1;//暂停

uint8_t cursor_mode = 0;//光标模式
uint16_t x1;//光标x1位置
uint16_t x2;//光标x2位置
uint16_t y1;//光标y1位置
uint16_t y2;//光标y2位置

uint8_t dac_wave=0;//dac波形
uint8_t dac_att=0;//dac衰减
uint32_t dac_freq=1000000;//dac频率
uint32_t poff = 0;
uint16_t number_ch=0;//dac??????

bool adjust=1;//0为粗调 1为细调


KEY key[10]={
	[0]={0,0,0,0,0,0,0,0},
	[1]={0,0,0,0,0,0,0,0},
	[2]={0,0,0,0,0,0,0,0},
	[3]={0,0,0,0,0,0,0,0},
	[4]={0,0,0,0,0,0,0,0},
	[5]={0,0,0,0,0,0,0,0},
	[6]={0,0,0,0,0,0,0,0},
	[7]={0,0,0,0,0,0,0,0},
	[8]={0,0,0,0,0,0,0,0},
	[9]={0,0,0,0,0,0,0,0},
};
uint8_t EC11_flag1=0, EC11_flag2=0;

//对应10个档位5 10 20 50 100 200 500 1000 2000 5000 mV
Calibration ch1_cali[10]={
	{600,2330,1}, //5mV
	{900,2435,1}, //10mV
	{1300,2485,1},//20mV 
	{1850,2520,1},//50mV
	{2270,2530,1},//100mV
	{2675,2530,1},//200mV
	{1425,2530,0},//500mV
	{1840,2535,0},//1V
	{2270,2540,0},//2V
	{2740,2535,0},//5V
};

Calibration ch2_cali[10]={
	{600,2280,1}, //5mV
	{860,2395,1}, //10mV
	{1290,2450,1},//20mV
	{1850,2486,1},//50mV	
	{2250,2495,1},//100mV
	{2651,2500,1},//200mV
	{1400,2495,0},//500mV
	{1815,2500,0},//1V
	{2240,2500,0},//2V
	{2715,2500,0},//5V
};

Calibration ch1_gear_now;
Calibration ch2_gear_now;

uint16_t reg[32];


void update_reg(uint8_t address){
	switch(address){
		case 0:
			reg[0] = ch2_att<<5 | ch1_att<<4 | ch2_on<<3 | ch1_on<<2 | ch<<1 | acdc;  
			break;
		case 1:
			reg[1] =  (cursor_mode&0x3)<<13 | stop<<4 | trig_ch<<3 | trig_edge<<2 | (trig_mode&0x3) ;
			break;
		case 2:
			reg[address] = ch1_gear;
			break;
		case 3:
			reg[address] = ch2_gear;
			break;
		case 4:
			reg[address] = ch1_offset;
			break;
		case 5:
			reg[address] = ch2_offset;
			break;
		case 6:
			reg[address] = trig_level&0xff;
			break;
		case 7:
			reg[address] = time_gear;
			break;
		case 8:
			reg[address] = time_offset;
			break;
		case 9:
			reg[address] = time_step;
			break;
		case 10:
			reg[address] = y1;
			break;
		case 11:
			reg[address] = y2;
			break;
		case 12:
			reg[address] = x1;
			break;
		case 13:
			reg[address] = x2;
			break;
		case 14:
			reg[address] = object;
			break;
		case 15:
			reg[address] = ((dac_att<<8)&0xFF00) | dac_wave&0xFF;
			break;
		case 16://需要同时写两个寄存器
			poff = (unsigned int)(dac_freq*42.94967296);
			SPI_WriteRegister(16, poff&0xFFFF);
			SPI_WriteRegister(17, (poff>>16)&0xFFFF);
			SPI_WriteRegister(18, dac_freq&0xFFFF);
			SPI_WriteRegister(19, (dac_freq>>16)&0xFFFF);
			return;break;
		case 20:
			reg[address] = number_ch;
			break;
		default:break;
	}
	SPI_WriteRegister(address, reg[address]);
}

void ctrl_init(){
	rcu_periph_clock_enable(RCU_GPIOB);
	rcu_periph_clock_enable(RCU_GPIOA);
	gpio_init(GPIOA, GPIO_MODE_OUT_PP, GPIO_OSPEED_MAX, GPIO_PIN_11); 
	gpio_init(GPIOA, GPIO_MODE_OUT_PP, GPIO_OSPEED_MAX, GPIO_PIN_12); 
	gpio_init(GPIOB, GPIO_MODE_OUT_PP, GPIO_OSPEED_MAX, GPIO_PIN_0); 
	gpio_init(GPIOB, GPIO_MODE_OUT_PP, GPIO_OSPEED_MAX, GPIO_PIN_9); 
  gpio_bit_set(GPIOB, GPIO_PIN_9);//ch1_att 1:no att 0:att
	gpio_bit_set(GPIOA, GPIO_PIN_11);//ch1_acdc 1:dc 0:ac
	gpio_bit_set(GPIOA, GPIO_PIN_12);//ch2_acdc 1:dc 0:ac
	gpio_bit_set(GPIOB, GPIO_PIN_0);//ch2_att 1:no att 0:att
}

void update_ch_gear(){
	if(ch==0){
		ch1_gear_now.dac_poff=ch1_cali[ch1_gear].dac_poff;
		ch1_gear_now.vertical_offset=ch1_cali[ch1_gear].vertical_offset - (ch1_offset-512);
		ch1_gear_now.gain_sel=ch1_cali[ch1_gear].gain_sel;
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		if(ch1_gear_now.gain_sel){
			gpio_bit_set(GPIOB, GPIO_PIN_9);//ch1_att 1:no att 0:att
		}else{
			gpio_bit_reset(GPIOB, GPIO_PIN_9);//ch1_att 1:no att 0:att
		}
	}
	else{
		ch2_gear_now.dac_poff=ch2_cali[ch2_gear].dac_poff;
		ch2_gear_now.vertical_offset=ch2_cali[ch2_gear].vertical_offset - (ch2_offset-512);
		ch2_gear_now.gain_sel=ch2_cali[ch2_gear].gain_sel;
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		mcp4728_write_all_channel(ch1_gear_now.dac_poff, ch2_gear_now.dac_poff, ch1_gear_now.vertical_offset, ch2_gear_now.vertical_offset);
		if(ch2_gear_now.gain_sel){
			gpio_bit_set(GPIOB, GPIO_PIN_0);//ch2_att 1:no att 0:att
		}else{
			gpio_bit_reset(GPIOB, GPIO_PIN_0);//ch2_att 1:no att 0:att
		}
	}
	delay_ms(100);
}




