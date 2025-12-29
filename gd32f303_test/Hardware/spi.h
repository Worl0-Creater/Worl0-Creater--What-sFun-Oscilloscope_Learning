#ifndef SPI
#define SPI

#include "systick.h"
#include "gd32f30x.h"
#include "stdio.h"


// 定义引脚
#define SPI_GPIO_PORT   	GPIOA
#define SPI_PIN_CS          GPIO_PIN_1
#define SPI_PIN_WR          GPIO_PIN_0  //WR高为写
#define SPI_PIN_SCK         GPIO_PIN_5
#define SPI_PIN_MOSI        GPIO_PIN_7
#define SPI_PIN_MISO        GPIO_PIN_6
#define SPI_INSTANCE    	SPI0

void bsp_spi_init();
uint16_t SPI_ReadRegister(uint8_t address);
void SPI_WriteRegister(uint8_t address, uint16_t data);

#endif

