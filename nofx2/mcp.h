#ifndef MCP_H_
#define MCP_H_

#include <stdio.h>
#include <stdlib.h>
#include "libmcp2221/win/win.h"
#include "libmcp2221/libmcp2221.h"
#include "libmcp2221/hidapi.h"

mcp2221_t *mcp_ara_open();
mcp_ara_close(mcp2221_t *dev);
int mcp_ara_i2c_write(mcp2221_t *myDev,
		      uint8_t addr,
		      uint8_t *data,
		      int length);
int mcp_ara_i2c_read(mcp2221_t *myDev,
		     uint8_t addr,
		     uint8_t *data,
		     int length);

#endif
