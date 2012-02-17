require 'heatmiser_crc'
require 'thread'
require 'timeout'
require 'socket'

class Heatmiser

  def initialize hostname, pin
    @data = {
        :hostname => hostname,
        :pin => pin,
        :lastStatus => nil,
        :timestamp => Time.now,
        :commandQueue => [],
        :queueMutex => Mutex.new,
        :statusMutex => Mutex.new
    }
  end

  def monitor
    @thread = Thread.new @data do | data |
      TCPSocket.open data[:hostname], 8068 do | socket |
        queueMutex = data[:queueMutex]
        statusMutex = data[:statusMutex]
        commandQueue = data[:commandQueue]
        pin = data[:pin]
        queryCommand = addCRCToCommand [0x93, 0x0B, 0x00, pin & 0xFF, pin >> 8, 0x00, 0x00, 0xFF, 0xFF]
        loop do
          sleep 1
          command = queryCommand
          queueMutex.synchronize do
            command = commandQueue.shift if commandQueue.size > 0
          end
          begin
            socket.write command.pack('c*')
            status = nil
            timeout 1 do
              status = socket.read(81).unpack('c*')
            end
            timestamp = Time.now
            crcHi = status.pop
            crcLo = status.pop
            crc = HeatmiserCRC.new status
            if crc.crcHi == crcHi and crc.crcLo == crcLo
              status << crcLo
              status << crcHi
              statusMutex.synchronize do
                data[:lastStatus] = status
                data[:timestamp] = timestamp
              end
            end
          rescue
          end
        end
      end
    end.run
  end

  def sensedTemperature
    @data[:statusMutex].synchronize do
      status = @data[:lastStatus]
      status && ((status[44] & 0xFF) | ((status[45] << 8) & 0xFF00)) / 10.0
    end
  end

  def wait
    @thread.join
  end

  def addCRCToCommand command
    crc = HeatmiserCRC.new command
    command << crc.crcLo
    command << crc.crcHi
    command
  end

end

hm = Heatmiser.new(ARGV[0], Integer(ARGV[1]))
hm.monitor
loop do
  sleep 1
  puts hm.sensedTemperature
end
