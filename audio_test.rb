require "thread"
require "fftw3"
require "coreaudio"


class Sound
  def initialize

  end

  def list_devices
    devices = CoreAudio.devices     # => An Array of Device objects
    #Each Device object has attributes that wrap the various properties provided by the host operating system. For example, to get a list of device names...

    devices.each do |device|
      puts "Device infi: #{device.inspect}"
      puts "Device Name: #{device.name} "
      if (device.name == "Loopback Audio") then
        @device = device
      end
    end

    puts "Selected Device Name: #{@device.name} "
  end


  def get_output
    puts "getting streams from #{@device.name} "
    @device.start do |*args|
      # Do something fancy
      streams = @device.streams
      streams.each do |stream|
        puts "Stream info: #{stream.inspect}"
        puts "Stream channels: #{stream.virtual_format.channels.inspect}"
      end
      
    end
  end


  def record_file_from_stream
    buf = @device.input_buffer(1024)

    wav = CoreAudio::AudioFile.new("sample.wav", :write, :format => :wav,
                                   :rate => @device.nominal_rate,
                                   :channels => @device.input_stream.channels)

    samples = 0
    th = Thread.start do
      loop do
        w = buf.read(4096)
        samples += w.size / @device.input_stream.channels
        wav.write(w)
      end
    end

    buf.start;
    $stdout.print "RECORDING..."
    $stdout.flush
    sleep 5;
    buf.stop
    $stdout.puts "done."
    th.kill.join

    wav.close

    puts "#{samples} samples read."
    puts "#{buf.dropped_frame} frame dropped."
  end

  def process_input_stream
    Thread.abort_on_exception = true

    inbuf = CoreAudio.default_input_device.input_buffer(1024)
    outbuf = CoreAudio.default_output_device.output_buffer(1024)

    queue = Queue.new
    pitch_shift_th = Thread.start do
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
        outbuf << FFTW3.ifft(f, 1) / w.shape[1]
      end
    end

    th = Thread.start do
      loop do
        wav = inbuf.read(1024)
        queue.push(wav)
      end
    end

    inbuf.start
    outbuf.start
    $stdout.print "loopback..."
    $stdout.flush
    sleep 10;
    queue.push(nil)
    inbuf.stop
    outbuf.stop
    $stdout.puts "done."
    th.kill.join
    pitch_shift_th.kill.join

    puts "#{inbuf.dropped_frame} frame dropped at input buffer."
    puts "#{outbuf.dropped_frame} frame dropped at output buffer."
  end

end

audio=Sound.new
audio.list_devices
#audio.get_output
audio.process_input_stream
