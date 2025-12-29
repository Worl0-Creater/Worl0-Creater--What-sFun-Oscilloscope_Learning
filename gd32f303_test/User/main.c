#include "gd32f30x.h"
#include <stdio.h>
#include "main.h"
#include "systick.h"
#include "platform.h"
#include <math.h>



void object_task();
void TRIG_CH_task();
void TRIG_EDGE_task();
void TRIG_MODE_task();
void TRIG_LEVEL_task();
void CH1_GEAR_task();
void CH1_OFFSET_task();
void CH2_GEAR_task();
void CH2_OFFSET_task();
void TIME_GEAR_task();
void TIME_OFFSET_task();
void DAC_WAVE_task();
void DAC_FREQ_task();
void DAC_ATT_task();
void CURSOR_X1_task();
void CURSOR_X2_task();
void CURSOR_Y1_task();
void CURSOR_Y2_task();




void object_task(){
	switch(object){
		case 0: TRIG_CH_task(); break;
		case 1: TRIG_EDGE_task(); break;
		case 2: TRIG_LEVEL_task(); break;
		case 3: CH1_GEAR_task(); break;
		case 4: CH1_OFFSET_task(); break;
		case 5: CH2_GEAR_task(); break;
		case 6: CH2_OFFSET_task(); break;
		case 7: TIME_GEAR_task(); break;
		case 8: TIME_OFFSET_task(); break;
		case 9: DAC_WAVE_task(); break;
		case 10: DAC_FREQ_task(); break;
		case 11: DAC_ATT_task(); break;
		case 12: CURSOR_X1_task(); break;
		case 13: CURSOR_X2_task(); break;
		case 14: CURSOR_Y1_task(); break;
		case 15: CURSOR_Y2_task(); break;
		default:object=0;break;
	}
	//以下是不分控件的
	if(key[0].signed_flag){
		key[0].signed_flag=0;
		acdc=!acdc;   
		if(!acdc){
			gpio_bit_set(GPIOA, GPIO_PIN_11);//ch1_acdc 1:dc 0:ac
			gpio_bit_set(GPIOA, GPIO_PIN_12);//ch2_acdc 1:dc 0:ac
		}
		else{
			gpio_bit_reset(GPIOA, GPIO_PIN_11);//ch1_acdc 1:dc 0:ac
			gpio_bit_reset(GPIOA, GPIO_PIN_12);//ch2_acdc 1:dc 0:ac
		}
		update_reg(0); 
	}
	else if(key[1].signed_flag){
		key[1].signed_flag=0;
		ch=!ch;   
		update_reg(0);
		if(object==3){object=5; update_reg(14);}
		else if(object==4){object=6; update_reg(14);}
		else if(object==5){object=3; update_reg(14);}
		else if(object==6){object=4; update_reg(14);}
	}
	else if(key[2].signed_flag){
		key[2].signed_flag=0;
		if(ch==0) ch1_on = !ch1_on;
		else ch2_on = !ch2_on;
		update_reg(0); 
	}
	else if(key[3].signed_flag){
		key[3].signed_flag=0;
		cursor_mode = (cursor_mode + 1) % 4; 
		update_reg(1);
	}
	else if(key[4].signed_flag){
		key[4].signed_flag=0;
		trig_mode = 0;//自动触发
		update_reg(1);
	}
	else if(key[5].signed_flag){
		key[5].signed_flag=0;
		trig_mode = 1;//正常触发
		update_reg(1);
	}
	else if(key[6].signed_flag){
		key[6].signed_flag=0;
		trig_mode = 2;//单次   
		update_reg(1);
	}
	else if(key[7].signed_flag){
		key[7].signed_flag=0;
		stop = !stop; 
		update_reg(1);
	}
}

int main(void)
{
	systick_config();
	usart_init();
	printf("helloworld\n");
	bsp_spi_init();
	timer2_init();
	I2C_Init();
	ctrl_init();
	for(int i=0;i<17;i++){
		update_reg(i);
	}
	update_reg(20);
	update_ch_gear();
	update_reg(6);
	while(1){	
		object_task();
	}
}

void TRIG_CH_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object++; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object=11; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		trig_ch=!trig_ch;
		update_reg(1);
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		trig_ch=!trig_ch;
		update_reg(1);
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		
	}
}

void TRIG_EDGE_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object++; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object--; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		trig_edge=!trig_edge;
		update_reg(1);
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		trig_edge=!trig_edge;
		update_reg(1);
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		
	}
}

void TRIG_LEVEL_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		if(!ch){ object++; update_reg(14);}
		else {object=5; update_reg(14);}
	}else if(EC11_flag1 == 1){
		EC11_flag1=0; 
		object--; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		if(adjust){
			trig_level=(trig_level <= 245) ? (trig_level + 10): 255;  update_reg(6);	
		}else{
			trig_level=(trig_level <= 254) ? (trig_level + 1): 255;  update_reg(6);
		}
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		if(adjust){
			trig_level = (trig_level >= 10) ? (trig_level - 10) : 0;  update_reg(6);
		}else{
			trig_level = (trig_level >= 1) ? (trig_level - 1) : 0;  update_reg(6);
		}
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		adjust=!adjust;
	}
}

void CH1_GEAR_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object++; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object--; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		ch1_gear=(ch1_gear <= 8) ? (ch1_gear + 1): 9;  update_reg(2);
		update_ch_gear();
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		ch1_gear=(ch1_gear >= 1) ? (ch1_gear - 1): 0;  update_reg(2);
		update_ch_gear();
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		
	}
}

void CH1_OFFSET_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object=7; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object--; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		if(adjust){
			ch1_offset=(ch1_offset <= 994) ? (ch1_offset + 10): 999;  update_reg(4); update_ch_gear();
		}else{
			ch1_offset=(ch1_offset <= 998) ? (ch1_offset + 1): 999;  update_reg(4); update_ch_gear();
		}
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		if(adjust){
			ch1_offset = (ch1_offset >= 10) ? (ch1_offset - 10) : 0;  update_reg(4); update_ch_gear();
		}else{
			ch1_offset = (ch1_offset >= 1) ? (ch1_offset - 1) : 0;  update_reg(4); update_ch_gear();
		}
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		adjust=!adjust;
	}
}

void CH2_GEAR_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object++; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object=2; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		ch2_gear=(ch2_gear <= 8) ? (ch2_gear + 1): 9;  update_reg(3);
		update_ch_gear();
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		ch2_gear=(ch2_gear >= 1) ? (ch2_gear - 1): 0;  update_reg(3);
		update_ch_gear();
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		
	}
}

void CH2_OFFSET_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object++; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object--; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		if(adjust){
			ch2_offset=(ch2_offset <= 994) ? (ch2_offset + 10): 999;  update_reg(5); update_ch_gear();
			
		}else{
			ch2_offset=(ch2_offset <= 998) ? (ch2_offset + 1): 999;  update_reg(5); update_ch_gear();
		}
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		if(adjust){
			ch2_offset = (ch2_offset >= 10) ? (ch2_offset - 10) : 0;  update_reg(5);
		}else{
			ch2_offset = (ch2_offset >= 1) ? (ch2_offset - 1) : 0;  update_reg(5);
		}
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		adjust=!adjust;
	}
}

void TIME_GEAR_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object=9; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		if(ch){ object--; update_reg(14);}
		else {object=4; update_reg(14);}
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		if(time_gear<20){ time_gear++;  update_reg(7);}
		switch(time_gear){
			case 1:time_step=1; update_reg(9); break;
			case 2:time_step=2; update_reg(9); break;
			case 3:time_step=4; update_reg(9); break;
			case 4:time_step=10; update_reg(9); break;
			case 5:time_step=20; update_reg(9); break;
			case 6:time_step=40; update_reg(9); break;
			case 7:time_step=25; update_reg(9); break;
			case 8:time_step=40; update_reg(9); break;
			case 9:time_step=40; update_reg(9); break;
			case 10:time_step=40; update_reg(9); break;
			case 11:time_step=40; update_reg(9); break;
			case 12:time_step=40; update_reg(9); break;
			case 13:time_step=40; update_reg(9); break;
			case 14:time_step=40; update_reg(9); break;
			case 15:time_step=40; update_reg(9); break;
			case 16:time_step=40; update_reg(9); break;
			case 17:time_step=40; update_reg(9); break;
			case 18:time_step=40; update_reg(9); break;
			case 19:time_step=40; update_reg(9); break;
			case 20:time_step=40; update_reg(9); break;
		}
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		if(time_gear>1) {time_gear--; update_reg(7);}
		switch(time_gear){
			case 1:time_step=1; update_reg(9); break;
			case 2:time_step=2; update_reg(9); break;
			case 3:time_step=4; update_reg(9); break;
			case 4:time_step=10; update_reg(9); break;
			case 5:time_step=20; update_reg(9); break;
			case 6:time_step=40; update_reg(9); break;
			case 7:time_step=25; update_reg(9); break;
			case 8:time_step=40; update_reg(9); break;
			case 9:time_step=40; update_reg(9); break;
			case 10:time_step=40; update_reg(9); break;
			case 11:time_step=40; update_reg(9); break;
			case 12:time_step=40; update_reg(9); break;
			case 13:time_step=40; update_reg(9); break;
			case 14:time_step=40; update_reg(9); break;
			case 15:time_step=40; update_reg(9); break;
			case 16:time_step=40; update_reg(9); break;
			case 17:time_step=40; update_reg(9); break;
			case 18:time_step=40; update_reg(9); break;
			case 19:time_step=40; update_reg(9); break;
			case 20:time_step=40; update_reg(9); break;
		}
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		
	}
}

void TIME_OFFSET_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object++; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object--; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		if(adjust){
			time_offset=(time_offset <= 245) ? (time_offset + 10): 255;  update_reg(8);
		}else{
			time_offset=(time_offset <= 254) ? (time_offset + 1): 255;  update_reg(8);
		}
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		if(adjust){
			time_offset = (time_offset >= 10) ? (time_offset - 10) : 0;  update_reg(8);
		}else{
			time_offset = (time_offset >= 1) ? (time_offset - 1) : 0;  update_reg(8);
		}
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		adjust=!adjust;
	}
}

void DAC_WAVE_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object++; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object=7; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		dac_wave=(dac_wave+1)%4;
		update_reg(15);
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		dac_wave=(dac_wave-1)%4;
		update_reg(15);
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		
	}
}

void DAC_FREQ_task(){
	static bool check = 0;
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		if(!check){
			object++; update_reg(14);
		}
		else{
			number_ch = (number_ch <= 6) ? (number_ch + 1) : 7;  update_reg(20);
		}
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		if(!check){
			object--; update_reg(14);
		}
		else{
			number_ch = (number_ch >= 1) ? (number_ch - 1) : 0;  update_reg(20);
		}
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		if(check)
			dac_freq = ((dac_freq + pow(10,number_ch)) <= 40000000) ? (dac_freq + pow(10,number_ch)) : 40000000;  
		update_reg(16);
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		if(check)
			dac_freq = ((dac_freq - pow(10,number_ch)) >= 0) ? (dac_freq - pow(10,number_ch)) : 0;  
		update_reg(16);
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		check = !check;
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		
	}
}

void DAC_ATT_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object=0; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object--; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;
		dac_att=(dac_att+1)%8;
		update_reg(15);
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;
		dac_att=(dac_att-1)%8;
		update_reg(15);
	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		
	}
}

void CURSOR_X1_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object++; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object--; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;

	}else if(EC11_flag2 == 2){
		EC11_flag2=0;

	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		adjust=!adjust;
	}
}

void CURSOR_X2_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object++; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object--; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;

	}else if(EC11_flag2 == 2){
		EC11_flag2=0;

	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		adjust=!adjust;
	}
}

void CURSOR_Y1_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object++; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object--; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;

	}else if(EC11_flag2 == 2){
		EC11_flag2=0;

	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		adjust=!adjust;
	}
}

void CURSOR_Y2_task(){
	if(EC11_flag1 == 2){
		EC11_flag1=0;
		object=0; update_reg(14);
	}else if(EC11_flag1 == 1){
		EC11_flag1=0;
		object--; update_reg(14);
	}else if(EC11_flag2 == 1){
		EC11_flag2=0;

		
	}else if(EC11_flag2 == 2){
		EC11_flag2=0;

	}else if(key[8].signed_flag==1){
		key[8].signed_flag=0;
		
	}
	else if(key[9].signed_flag==1){
		key[9].signed_flag=0;
		adjust=!adjust;
	}
}










