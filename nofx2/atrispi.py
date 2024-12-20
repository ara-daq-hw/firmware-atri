

class atrispi:
    def __init__(self, infn = "/dev/xillybus_spi_in", outfn = "/dev/xillybus_spi_out"):
        self.infn = infn
        self.outfn = outfn
        self.sin = None
        self.sout = None

    def command(self, val, dummy_bytes, read_bytes, data_in = bytes()):
        # construct the message
        msg = bytes([val])+data_in+b'\x00'*(dummy_bytes+read_bytes)
        # send it
        rv = self.send(msg)
        return rv[1+len(data_in)+dummy_bytes:]

    def send(self, msg):
        self.sin = open(self.infn, "wb")
        self.sout = open(self.outfn, "rb")
        # we should be able to just write everything
        self.sin.write(msg)
        self.sin.flush()
        # and now read an equivalent amount
        rb = self.sout.read(len(msg))
        self.sin.close()
        self.sout.close()
        self.sin = None
        self.sout = None
        return rb
