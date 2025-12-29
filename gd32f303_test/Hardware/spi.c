#include "spi.h"



void bsp_spi_init(){
	rcu_periph_clock_enable(RCU_GPIOA);
	rcu_periph_clock_enable(RCU_SPI0); 
	rcu_periph_clock_enable(RCU_AF);
	gpio_pin_remap_config(GPIO_SPI0_REMAP,DISABLE);
	gpio_init(SPI_GPIO_PORT, GPIO_MODE_AF_PP, GPIO_OSPEED_MAX, SPI_PIN_SCK);  //SCK
	gpio_init(SPI_GPIO_PORT, GPIO_MODE_IN_FLOATING, GPIO_OSPEED_MAX, SPI_PIN_MISO);  //MISO
	gpio_init(SPI_GPIO_PORT, GPIO_MODE_AF_PP, GPIO_OSPEED_MAX, SPI_PIN_MOSI);  //MOSI
	gpio_init(SPI_GPIO_PORT, GPIO_MODE_OUT_PP, GPIO_OSPEED_MAX, SPI_PIN_CS); //CS
	gpio_init(SPI_GPIO_PORT, GPIO_MODE_OUT_PP, GPIO_OSPEED_MAX, SPI_PIN_WR); //WR
	gpio_bit_set(SPI_GPIO_PORT, SPI_PIN_CS);  //CS置高
	gpio_bit_reset(SPI_GPIO_PORT, SPI_PIN_WR); // WR置低
	
	//SPI参数定义结构体
	spi_parameter_struct spi_init_struct;
	spi_init_struct.trans_mode            = SPI_TRANSMODE_FULLDUPLEX;         //传输模式全双工
	spi_init_struct.device_mode           = SPI_MASTER;                       //配置为主机
	spi_init_struct.frame_size            = SPI_FRAMESIZE_8BIT;               //8位数据
	spi_init_struct.clock_polarity_phase  = SPI_CK_PL_LOW_PH_1EDGE;          //极性相位
	spi_init_struct.nss                   = SPI_NSS_SOFT;                     //软件cs
	spi_init_struct.prescale              = SPI_PSC_8;                        //SPI时钟预调因数为2
	spi_init_struct.endian                = SPI_ENDIAN_MSB;                   //高位在前
	//将参数填入SPI0
	spi_init(SPI0, &spi_init_struct);
	//使能SPI
	spi_enable(SPI0);
}



// 写寄存器函数
void SPI_WriteRegister(uint8_t address, uint16_t data) {
    // 组合发送数据：地址 + 高8位 + 低8位
    uint8_t tx_buf[3] = {address, (data >> 8) & 0xFF, data & 0xFF};

    gpio_bit_reset(SPI_GPIO_PORT, SPI_PIN_CS);
    gpio_bit_set(SPI_GPIO_PORT, SPI_PIN_WR);// 设置WR为写模式（高电平）

    for (int i = 0; i < 3; i++) {
        while (spi_i2s_flag_get(SPI_INSTANCE, SPI_FLAG_TBE) == RESET);
        spi_i2s_data_transmit(SPI_INSTANCE, tx_buf[i]);
        while (spi_i2s_flag_get(SPI_INSTANCE, SPI_STAT_RBNE) == RESET);
        spi_i2s_data_receive(SPI_INSTANCE);
    }

    gpio_bit_set(SPI_GPIO_PORT, SPI_PIN_CS);
	gpio_bit_reset(SPI_GPIO_PORT, SPI_PIN_WR);
}

// 读寄存器函数
uint16_t SPI_ReadRegister(uint8_t address) {
    uint8_t tx_buf[3] = {address, 0xFF, 0xFF}; // 发送地址和填充字节
    uint8_t rx_buf[3];

    gpio_bit_reset(SPI_GPIO_PORT, SPI_PIN_CS);
    // 设置WR为读模式（低电平）
    gpio_bit_reset(SPI_GPIO_PORT, SPI_PIN_WR);

    for (int i = 0; i < 3; i++) {

        while (spi_i2s_flag_get(SPI_INSTANCE, SPI_FLAG_TBE) == RESET);
        spi_i2s_data_transmit(SPI_INSTANCE, tx_buf[i]);
        while (spi_i2s_flag_get(SPI_INSTANCE, SPI_STAT_RBNE) == RESET);
        rx_buf[i] = spi_i2s_data_receive(SPI_INSTANCE);
    }

    gpio_bit_set(SPI_GPIO_PORT, SPI_PIN_CS);

    // 组合返回的16位数据（高8位+低8位）
    return ((uint16_t)rx_buf[1] << 8) | rx_buf[2];
}


