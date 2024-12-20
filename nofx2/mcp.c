#include "mcp.h"

mcp2221_t *mcp_ara_open() {
  mcp2221_init();
  int count = mcp2221_find(MCP2221_DEFAULT_VID,
			   MCP2221_DEFAULT_PID,
			   NULL, NULL, NULL);
  if (!count) {
    fprintf(stderr, "fatal error: could not find MCP2221!");
    mcp2221_exit();
    return NULL;
  }
  mcp2221_t *dev = mcp2221_open();
  mcp2221_gpioconfset_t gpioConf = mcp2221_GPIOConfInit();

  gpioConf.conf[0].gpios          = MCP2221_GPIO0 | MCP2221_GPIO1 | MCP2221_GPIO2 | MCP2221_GPIO3;
  gpioConf.conf[0].mode           = MCP2221_GPIO_MODE_GPIO;
  gpioConf.conf[0].direction      = MCP2221_GPIO_DIR_OUTPUT;
  gpioConf.conf[0].value          = MCP2221_GPIO_VALUE_LOW;

  mcp2221_setGPIOConf(myDev, &gpioConf);

  mcp2221_i2c_state_t state = MCP2221_I2C_IDLE;
  mcp2221_i2cState(myDev, &state);
  if (state != MCP2221_I2C_IDLE)
    mcp2221_i2cCancel(myDev);
  mcp2221_i2cDivider(myDev, 260);

  return myDev;
}

void mcp_ara_close(mcp2221_t *myDev) {
  mcp2221_close(myDev);
  mcp2221_exit();
}

// we need exactly 2 functions
// read bytes from I2C
// write bytes to I2C
// return 0 if OK -1 if nak
int mcp_ara_i2c_write(mcp2221_t *myDev,
		       uint8_t addr,
		       uint8_t *data,
		       int length) {
  mcp2221_i2c_state_t state;
  mcp2221_i2c_status_t status;
  
  mcp2221_i2cWrite(myDev, addr, data, length, MCP2221_I2CRW_NORMAL);
  while (1) {
    mcp2221_i2cFullStatus(myDev, &state, &status);
    if (state == MCP2221_I2C_IDLE || status != MCP2221_I2C_OK)
      break;
  }
  if (status != MCP2221_I2C_OK)
    return -1;
  return 0;
}

int mcp_ara_i2c_read(mcp2221_t *myDev,
		     uint8_t addr,
		     uint8_t *data,
		     int length) {
  mcp2221_i2c_state_t state;
  mcp2221_i2c_status_t status;

  mcp2221_i2cRead(myDev, addr, length, MCP2221_I2CRW_NORMAL);
  while (1) {
    mcp2221_i2cState(myDev, &state);
    if (state == MCP2221_I2C_DATAREADY || state == MCP2221_I2C_ADDRNOTFOUND)
      break;
  }
  if (state == MCP2221_I2C_DATAREADY) {
    mcp2221_i2cGet(myDev, data, length);
    return 0;
  }
  return -1;
}

// we are trying to replace atriControlLib:
// we sleazeball this by just replacing
// sendVendorRequest.
// bmRequestType = VR_HOST_TO_DEVICE
// bRequest = VR_ATRI_I2C
// wValue = i2cAddress
// wIndex = 0
// dataLength = length
// read is exactly the same except bmRequestType is VR_DEVICE_TO_HOST
int sendVendorRequest(uint8_t bmRequestType,
		      uint8_t bRequest,
		      uint16_t wValue,
		      uint16_t wIndex,
		      unsigned char *data,
		      uint16_t wLength) {
  
}


