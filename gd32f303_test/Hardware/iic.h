#ifndef __IIC_H
#define __IIC_H

#include "gd32f30x.h"
#include "systick.h"
#include "platform.h"

// 定义 I2C 引脚和参数
#define I2C_SCL_PIN         GPIO_PIN_10    // PB10 -> SCL
#define I2C_SDA_PIN         GPIO_PIN_11    // PB11 -> SDA
#define I2C_GPIO_PORT       GPIOB          // 使用 GPIOB
#define I2C_GPIO_CLK        RCU_GPIOB      // GPIOB 时钟

#define MCP4728_ADDR	0xC0

#define MCP4728_Channel_A	0x01
#define MCP4728_Channel_B	0x03
#define MCP4728_Channel_C	0x05
#define MCP4728_Channel_D	0x06

//写函数
#define SCL_Pin_SET()		gpio_bit_set(I2C_GPIO_PORT, I2C_SCL_PIN)
#define SCL_Pin_RESET()		gpio_bit_reset(I2C_GPIO_PORT, I2C_SCL_PIN)
#define SDA_Pin_SET()		gpio_bit_set(I2C_GPIO_PORT, I2C_SDA_PIN)
#define SDA_Pin_RESET()	    gpio_bit_reset(I2C_GPIO_PORT, I2C_SDA_PIN)

//读取函数
#define SDA_Pin_READ()		gpio_input_bit_get(I2C_GPIO_PORT, I2C_SDA_PIN)


#define u32 uint32_t
#define u16 uint16_t
#define u8 uint8_t

void I2C_Init(void);
static void IIC_Start_MCP4728(void);
static void IIC_Stop(void);
uint8_t I2C1_Wait_Ack(void);
void I2C1_Ack(void);
void I2C1_NAck(void);
void I2C1_Send_One_Byte(uint8_t txd);
static void IIC_SendACK(uint8_t ack);
static uint8_t IIC_RecvACK(void);
static uint8_t IIC_SendByte(uint8_t dat);
uint8_t I2C1_Read_One_Byte(unsigned char ack);
static uint8_t IIC_RecvByte(void);
uint8_t MCP4728_ReadData(uint8_t* DataRcvBuf);
uint8_t MCP4728_ReadAddr(const uint8_t cs);
void change_address(uint8_t OldAddr, uint8_t Cmd_NewAdd, const uint8_t cs);
void MCP4728Init(void);
uint8_t MCP4728_SetVoltage(const uint8_t Addr, const uint8_t Channel, const uint16_t AnalogVol, const uint8_t WriteEEPROM);
int mcp4728_write_all_channel(u16 vol1, u16 vol2, u16 vol3, u16 vol4);
uint8_t MCP4728_reset();
uint8_t MCP4728_wakeup();

#endif /* __IIC_H */

