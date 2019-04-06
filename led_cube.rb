require 'serialport'
require "thread"
require "fftw3"
require "coreaudio"


class LedCube
  def initialize
  	init_arduino
  	init_audio
  end

  def init_arduino
    # defaults params for arduino serial
    @baud_rate = 115200
    @data_bits = 8
    @stop_bits = 1
    @parity = SerialPort::NONE

    # serial port
    @sp=nil
    @port=nil
  end

  def init_audio
  	devices = CoreAudio.devices     # => An Array of Device objects
    devices.each do |device|
      #puts "Device infi: #{device.inspect}"
      #puts "Device Name: #{device.name} "
      if (device.name == "Loopback Audio") then
        @device = device
      end
    end
    puts "Selected Device Name: #{@device.name} "
  end

  def open_serial port
    @sp = SerialPort.new(port, @baud_rate, @data_bits, @stop_bits, @parity)
  end


	def shutdown reason
		return if @sp==nil
		return if reason==:int

		printf("\nshutting down serial (%s)\n", reason)
	end

  #def read
  #    @sp.flush()
  #    printf("# R : reading ...\n")
  #    c=nil
  #    while c==nil
  #        c=@sp.read(1)
  #        break if c != nil
  #    end
  #    printf("# R : 0x%02x\n", c.ord)
  #    return c
  #    # @sp.readByte()
  #end
  def write_rgb(r, g, b)
    write(r.chr)
    write(g.chr)
    write(b.chr)
  end

  def write c
    @sp.putc(c)
    @sp.flush()
    #printf("# W : 0x%02x\n", c.ord)
  end

  def flush
    @sp.flush
  end

  def start
    Thread.abort_on_exception = true

    @inbuf = @device.input_buffer(1024)
    #outbuf = CoreAudio.default_output_device.output_buffer(1024)

    queue = Queue.new
    @pitch_shift_th = Thread.start do
      

      # process the audio
      while w = queue.pop
        half = w.shape[1] / 2
        f = FFTW3.fft(w, 1)
        shift = 12
        f.shape[0].times do |ch|
          f[ch, (shift+1)...half] = f[ch, 1...(half-shift)]
          f[ch, 1..shift] = 0
          f[ch, (half+1)...(w.shape[1]-shift)] = f[ch, (half+shift+1)..-1]
          f[ch, -shift..-1] = 0
        end
        #outbuf << FFTW3.ifft(f, 1) / w.shape[1]
        send_to_cube(FFTW3.ifft(f, 1) / w.shape[1])
      end
    end

    @th = Thread.start do
      loop do
        wav = inbuf.read(1024)
        queue.push(wav)
      end
    end
    
    @inbuf.start
    $stdout.print "loopback..."
    $stdout.flush
  end

  def stop
    @inbuf.stop
    $stdout.puts "done."
    @th.kill.join
    @pitch_shift_th.kill.join
    puts "#{@inbuf.dropped_frame} frame dropped at input buffer."
  end

end


# serial port should be connected to /dev/ttyUSB*
ports=Dir.glob("/dev/cu.usbmodem*")
if ports.size < 1
  printf("did not found right /dev/ttyUSB* serial")
  exit(1)
end

lc=LedCube.new()
lc.open(ports[0])

at_exit     { tty.shutdown :exit }
trap("INT") { tty.shutdown :int  ; exit}

# # print debug messages from serial port
# Thread.new do
#   loop do
#       puts "Serial says: #{tty.read}"
#     sleep(0.01)
#   end
# end


lc.start
sleep 10;
queue.push(nil)
lc.stop

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