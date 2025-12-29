#ifndef __TIMER_H
#define __TIMER_H

#include "systick.h"
#include "gd32f30x.h"
#include "stdio.h"
#include "string.h"
#include "stdlib.h"
#include "stdbool.h"




// º¯ÊýÉùÃ÷
void timer2_init(void);
void TIMER2_IRQHandler(void);
#endif // __TIMER_H