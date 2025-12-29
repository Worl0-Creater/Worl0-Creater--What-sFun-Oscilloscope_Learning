#include "iic.h"


void I2C_Init(void){
	rcu_periph_clock_enable(RCU_GPIOB);
	gpio_init(I2C_GPIO_PORT, GPIO_MODE_OUT_PP, GPIO_OSPEED_MAX, I2C_SCL_PIN); 
	gpio_init(I2C_GPIO_PORT, GPIO_MODE_OUT_PP, GPIO_OSPEED_MAX, I2C_SDA_PIN); 
}

static void IIC_Start_MCP4728(void)
{
    SDA_Pin_SET();               //拉高数据线SDA_Pin = 1;
    SCL_Pin_SET();               //拉高时钟线SCL_Pin = 1
    delay_us(4);                 //延时
    SDA_Pin_RESET();             //产生下降沿SDA_Pin = 0
    delay_us(4);                 //延时
    SCL_Pin_RESET();             //拉低时钟线SCL_Pin = 0
}

static void IIC_Stop(void)
{
    SCL_Pin_RESET();               //拉低时钟线SCL_Pin = 0
    SDA_Pin_RESET();             //拉低数据线SDA_Pin = 0
    delay_us(5);                 //延时
    SCL_Pin_SET();               //拉高时钟线SCL_Pin = 1
    SDA_Pin_SET();               //产生上升沿SDA_Pin = 1
    delay_us(5);   				 //延时
}

uint8_t I2C1_Wait_Ack(void)
{
    uint16_t ucErrTime = 0;
    SDA_Pin_SET();
    delay_us(1);
    SCL_Pin_SET();
    delay_us(1);
    while(SDA_Pin_READ() == 1)
    {
        ucErrTime++;
        if(ucErrTime>1000)
        {
            IIC_Stop();
            return 1;
        }
    }
    SCL_Pin_RESET();				//时钟输出0
    return 0;
}

void I2C1_Ack(void)
{
    SCL_Pin_RESET();
    SDA_Pin_RESET();
    delay_us(2);
    SCL_Pin_SET();
    delay_us(2);
    SCL_Pin_RESET();
}

void I2C1_NAck(void)
{
    SCL_Pin_RESET();
    SDA_Pin_SET();
    delay_us(2);
    SCL_Pin_SET();
    delay_us(2);
    SCL_Pin_RESET();
}

void I2C1_Send_One_Byte(uint8_t txd)
{
    uint8_t t;
    SCL_Pin_RESET();					//拉低时钟开始数据传输
    for(t=0; t<8; t++)    			//开始准备信号线
    {
        if (txd & 0x80) SDA_Pin_SET();  //送数据口SDA_Pin = CY;
        else SDA_Pin_RESET();
        txd<<=1;
        delay_us(2);  				 //这三个延时都是必须的
        SCL_Pin_SET();
        delay_us(2);
        SCL_Pin_RESET();
        delay_us(2);
    }
}

static void IIC_SendACK(uint8_t ack)
{
    if(ack!=0) SDA_Pin_SET();    //写应答信号SDA_Pin = ack
    else SDA_Pin_RESET();
    SCL_Pin_SET();               //拉高时钟线SCL_Pin = 1
    delay_us(5);                 //延时
    SCL_Pin_RESET();             //拉低时钟线SCL_Pin = 0
    delay_us(5);                 //延时
}

static uint8_t IIC_RecvACK(void)
{
    uint8_t rtn = 1;
    SCL_Pin_SET();               //拉高时钟线SCL_Pin = 1
    delay_us(5);                 //延时
    rtn = SDA_Pin_READ();        //读应答信号SDA_Pin
    SCL_Pin_RESET();             //拉低时钟线SCL_Pin = 0
    delay_us(20);                 //延时
    return rtn;
}

static uint8_t IIC_SendByte(uint8_t dat)
{
    uint8_t i;
    for (i=0; i<8; i++)                 //8位计数器
    {
        if (dat & 0x80) SDA_Pin_SET();  //送数据口SDA_Pin = CY;
        else SDA_Pin_RESET();
        delay_us(1);
        SCL_Pin_SET();                  //拉高时钟线SCL_Pin = 1
        delay_us(5);                    //延时
        SCL_Pin_RESET();                //拉低时钟线SCL_Pin = 0
        dat <<= 1;                      //移出数据的最高位
        delay_us(5);                    //延时
    }
    SDA_Pin_SET();						//SDA_Pin = 1
    return IIC_RecvACK();
}

uint8_t I2C1_Read_One_Byte(unsigned char ack)
{
    unsigned char i,receive=0;

    for(i=0; i<8; i++ )
    {
        SCL_Pin_RESET();
        delay_us(2);
        SCL_Pin_SET();
        receive<<=1;
        if(SDA_Pin_READ() == 1)
        {
            receive |= 1;
        }
        delay_us(1);
    }
    if (!ack)
        I2C1_NAck();					//发送nACK
    else
        I2C1_Ack(); 					//发送ACK
    return receive;
}

static uint8_t IIC_RecvByte(void)
{
    uint8_t i;
    uint8_t dat = 0;
    SDA_Pin_SET();				//使能内部上拉,准备读取数据,SDA_Pin = 1
    for (i=0; i<8; i++)         //8位计数器
    {
        dat <<= 1;
        SCL_Pin_SET();          //拉高时钟线SCL_Pin = 1
        delay_us(5);            //延时
        if(SDA_Pin_READ() == 1)
        {
            dat |= 0x01;
        }
        SCL_Pin_RESET();        //拉低时钟线SCL_Pin = 0
        delay_us(5);            //延时
    }
    return dat;
}

uint8_t MCP4728_ReadData(uint8_t* DataRcvBuf)
{
    uint8_t rt;
    uint8_t i;
    IIC_Start_MCP4728();
    rt = IIC_SendByte(MCP4728_ADDR + 1);//发送读地址
    if(rt == 1)
    {
        return 1;
    }
    for(i = 0; i < 23; i++)
    {
        DataRcvBuf[i] = IIC_RecvByte();
        IIC_SendACK(0);//发送应答
    }
    DataRcvBuf[i] = IIC_RecvByte();
    IIC_SendACK(1);//发送非应答
    IIC_Stop();
    return 0;
}

/* -------------------------------- begin  --------------------------------- */
/**
  * @Name    MCP4728_ReadAddr
  * @brief   读取地址
  * @param   cs: 片选信号
  * @retval  读取到的地址信息
  * @author 
  * @Data    2020-07-06
 **/
/* -------------------------------- end ------------------------------------ */
uint8_t MCP4728_ReadAddr(const uint8_t cs)
{
    uint8_t rt = 1;
    uint8_t ADDR_Read = 0;
    IIC_Start_MCP4728();
    I2C1_Send_One_Byte(0x00);//器件地址
    rt = I2C1_Wait_Ack();
    I2C1_Send_One_Byte(0x0C);
    rt = I2C1_Wait_Ack();
    IIC_Start_MCP4728();
    I2C1_Send_One_Byte(0xC1);
    rt = I2C1_Wait_Ack();
    ADDR_Read = I2C1_Read_One_Byte(0);
    IIC_Stop();
    ADDR_Read = ((ADDR_Read >> 4) & 0x0E) | 0xC0; //得到地址信息
    return ADDR_Read;
}

/* -------------------------------- begin  --------------------------------- */
/**
  * @Name    change_address
  * @brief   更改MCP4728地址
  * @param   OldAddr: 原本的地址
**			 Cmd_NewAdd: 想要修改的地址
**			 cs: [输入/出]
  * @retval  None
  * @author  
  * @Data    2020-07-10
 **/
/* -------------------------------- end ------------------------------------ */
void change_address(uint8_t OldAddr, uint8_t Cmd_NewAdd, const uint8_t cs)
{
    IIC_Start_MCP4728();
    I2C1_Send_One_Byte(OldAddr);	                       //器件地址
    I2C1_Wait_Ack();
    I2C1_Send_One_Byte(((OldAddr & 0x0E) << 1) | 0x61);    //发送命令+当前地址 0x61
    I2C1_Wait_Ack();
    I2C1_Send_One_Byte(((Cmd_NewAdd & 0x0E) << 1) | 0x62); //发送新地址
    I2C1_Wait_Ack();
    I2C1_Send_One_Byte(((Cmd_NewAdd & 0x0E) << 1) | 0x63); //确认发送新地址
    I2C1_Wait_Ack();
    IIC_Stop();							                   //产生一个停止条件
    delay_ms(20);
}

/* -------------------------------- begin  --------------------------------- */
/**
  * @Name    MCP4728Init
  * @brief   4728芯片初始化，若地址一样则重新配置为规定的地址
  * @param   None
  * @retval  None
  * @author  
  * @Data    2020-07-06
 **/
/* -------------------------------- end ------------------------------------ */
void MCP4728Init(void)
{
    uint8_t addr1;
    addr1 = MCP4728_ReadAddr(1); //读取第1片的地址
}

/* -------------------------------- begin  --------------------------------- */
/**
  * @Name    MCP4728_SetVoltage
  * @brief   设置MCP4728单个通道的电压
  * @param   Addr: 芯片地址
**			 Channel: 选择通道
**			 AnalogVol: 设置电压对应的模拟值
**			 WriteEEPROM: 是否同时写入芯片的EEPROM中，1写入，0不写入
  * @retval  返回设置结果
  * @author  
  * @Data    2020-06-29
 **/
/* -------------------------------- end ------------------------------------ */
uint8_t MCP4728_SetVoltage(const uint8_t Addr, const uint8_t Channel, const uint16_t AnalogVol, const uint8_t WriteEEPROM)
{
    uint8_t rt;
    uint8_t SendData;
    uint16_t temp_u16 = AnalogVol;
    temp_u16 = (temp_u16 > 4095) ? 4095 : temp_u16;
    IIC_Start_MCP4728();
    rt = IIC_SendByte(Addr);

    SendData = (WriteEEPROM == 1) ? 0x58|Channel : 0x40|Channel;
    rt = IIC_SendByte(SendData);

    SendData = 0x90 | (temp_u16>>8);
    rt = IIC_SendByte(SendData);

    SendData = temp_u16 & 0xFF;
    rt = IIC_SendByte(SendData);
    if(rt == 1)
    {
        return 0;
    }
    IIC_Stop();
    return 1;
}


int mcp4728_write_all_channel(u16 vol1, u16 vol2, u16 vol3, u16 vol4)
{
    u16 Dn[4];
    u8 h_byte[4];
    u8 l_byte[4];
    int i;
    
    Dn[0] = ( u16 )(vol1);
    Dn[1] = ( u16 )(vol2);
    Dn[2] = ( u16 )(vol3);
    Dn[3] = ( u16 )(vol4);
 
    for(i = 0; i < 4; i++){
        Dn[i] = Dn[i]&0x0FFF;
        Dn[i] = 0x8000|Dn[i];               // vref=1, PD0=0,PD1=0,Gx=0
 
        h_byte[i] = ( u8 )(Dn[i] >> 8);   
        l_byte[i] = ( u8 )(Dn[i]);
    }
 
    IIC_Start_MCP4728();
    IIC_SendByte( MCP4728_ADDR );
    IIC_SendByte( 0x40 );          // C2=0,C1=1,C0=0,W1=1,W2=0,DAC1=0,DAC0=0,
    IIC_SendByte( h_byte[0] );
    IIC_SendByte( l_byte[0] );
    IIC_SendByte( 0x42 );
    IIC_SendByte( h_byte[1] );
    IIC_SendByte( l_byte[1] );
		IIC_SendByte( 0x44 );
    IIC_SendByte( h_byte[2] );
    IIC_SendByte( l_byte[2] );
		IIC_SendByte( 0x46 );
    IIC_SendByte( h_byte[3] );
    IIC_SendByte( l_byte[3] );
		
    IIC_Stop();

    return 0;
}

uint8_t MCP4728_reset()
{
    uint8_t rt;
    uint8_t SendData;
    IIC_Start_MCP4728();
    rt = IIC_SendByte(MCP4728_ADDR);
	
    SendData = 0x06;
    rt = IIC_SendByte(SendData);
	
    if(rt == 1)
    {
        return 0;
    }
    IIC_Stop();
    return 1;
}


uint8_t MCP4728_wakeup()
{
    uint8_t rt;
    uint8_t SendData;
    IIC_Start_MCP4728();
    rt = IIC_SendByte(MCP4728_ADDR);
	
    SendData = 0x09;
    rt = IIC_SendByte(SendData);
	
    if(rt == 1)
    {
        return 0;
    }
    IIC_Stop();
    return 1;
}

