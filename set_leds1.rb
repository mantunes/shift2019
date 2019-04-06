require 'serialport'

class TTy
  def initialize
    # defaults params for arduino serial
    @baud_rate = 115200
    @data_bits = 8
    @stop_bits = 1
    @parity = SerialPort::NONE

    # serial port
    @sp=nil
    @port=nil
  end

  def open port
    @sp = SerialPort.new(port, @baud_rate, @data_bits, @stop_bits, @parity)
  end


  def shutdown reason
    return if @sp==nil
    return if reason==:int

    printf("\nshutting down serial (%s)\n", reason)
  end

  def read
        @sp.flush()
        printf("# R : reading ...\n")
        c=nil
        while c==nil
            c=@sp.read(1)
            break if c != nil
        end
        printf("# R : 0x%02x\n", c.ord)
        return c
        # @sp.readByte()
    end

  def write c
    @sp.putc(c)
    @sp.flush()
    #printf("# W : 0x%02x\n", c.ord)
  end

  def flush
    @sp.flush
  end
end


# serial port should be connected to /dev/ttyUSB*
ports=Dir.glob("/dev/cu.usbmodem*")
if ports.size < 1
  printf("did not found right /dev/ttyUSB* serial")
  exit(1)
end

tty=TTy.new()
tty.open(ports[0])

at_exit     { tty.shutdown :exit }
trap("INT") { tty.shutdown :int  ; exit}

# # print debug messages from serial port
# Thread.new do
#   loop do
#       puts "Serial says: #{tty.read}"
#     sleep(0.01)
#   end
# end

(1..).each do |i|
  # tty.write(((i * 2) % 256).chr)
  # tty.write(((i * 2) % 256).chr)
  # tty.write(((i * 2) % 256).chr)
  #tty.write(((i * 5) % 256).chr)
  #tty.write(((i * 9) % 256).chr)
  tty.write(1.chr)
  tty.write(1.chr)
  tty.write(1.chr)
  sleep 0.017
end