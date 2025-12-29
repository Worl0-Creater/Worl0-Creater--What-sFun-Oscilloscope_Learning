#ifndef UART
#define UART

#include "systick.h"
#include "gd32f30x.h"
#include "stdio.h"
#include "string.h"
#include "stdlib.h"

#define BSP_USART_IRQHandler  USART0_IRQHandler
#define USART_RECEIVE_LENGTH 256



#define BSP_USART_RCU             RCU_USART0
#define BSP_USART_TX_RCU          RCU_GPIOA
#define BSP_USART_RX_RCU          RCU_GPIOA
#define BSP_USART_IRQ             USART0_IRQn
#define BSP_USART    			  USART0

#define BSP_USART_TX_PORT      	GPIOA
#define BSP_USART_TX_PIN        GPIO_PIN_9
#define BSP_USART_RX_PORT       GPIOA
#define BSP_USART_RX_PIN        GPIO_PIN_10



//#define USART1_EN

#define USART1_TX_PORT       GPIOA
#define USART1_TX_PIN        GPIO_PIN_2
#define USART1_RX_PORT       GPIOA
#define USART1_RX_PIN        GPIO_PIN_3


void usart_init();
void usart_send_data(uint8_t ucch);
void usart_send_String(uint8_t *ucstr);
void usart1_send_data(uint8_t byte);
void usart1_send_String(uint8_t *ucstr);
uint8_t usart_receive_data();
uint8_t usart1_receive_data();



#endif

