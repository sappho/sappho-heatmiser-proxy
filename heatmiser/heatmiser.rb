require 'heatmiser_crc'
require 'thread'
require 'timeout'
require 'socket'

class Heatmiser

  def initialize hostname, pin
    @data = {
        :hostname => hostname,
        :pin => pin,
        :lastStatus => {
            :valid => false,
            :raw => [],
            :timestamp => Time.now,
            :sensedTemperature => 0.0,
            :requestedTemperature => 0
        },
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
        queryCommand = [0x93, 0x0B, 0x00, pin & 0xFF, pin >> 8, 0x00, 0x00, 0xFF, 0xFF]
        crc = HeatmiserCRC.new queryCommand
        queryCommand << crc.crcLo
        queryCommand << crc.crcHi
        loop do
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
            if (status[0] & 0xFF) == 0x94 and status[1] == 0x51 and status[2] == 0 and
                crc.crcHi == crcHi and crc.crcLo == crcLo
              status << crcLo
              status << crcHi
              statusMutex.synchronize do
                data[:lastStatus] = {
                    :valid => true,
                    :raw => status,
                    :timestamp => timestamp,
                    :sensedTemperature => ((status[44] & 0xFF) | ((status[45] << 8) & 0x0F00)) / 10.0,
                    :requestedTemperature => status[25] & 0xFF
                }
              end
            end
          rescue
          end
        end
      end
    end.run
  end

  def lastStatus
    @data[:statusMutex].synchronize do
      status = @data[:lastStatus]
      {
          :valid => status[:valid],
          :raw => status[:raw].dup,
          :timestamp => status[:timestamp],
          :sensedTemperature => status[:sensedTemperature],
          :requestedTemperature => status[:requestedTemperature]
      }
    end
  end

end

hm = Heatmiser.new(ARGV[0], Integer(ARGV[1]))
hm.monitor
loop do
  sleep 1
  status = hm.lastStatus
  puts "#{status[:timestamp]} #{status[:requestedTemperature]} #{status[:sensedTemperature]}" if status[:valid]
end
