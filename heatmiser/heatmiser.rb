require 'heatmiser_crc'
require 'thread'
require 'timeout'
require 'socket'

class Heatmiser

  def initialize hostname, pin
    @mutex = Mutex.new
    @data = {
        :hostname => hostname,
        :pin => pin,
        :lastStatus => {
            :valid => false,
            :raw => [],
            :timestamp => Time.now,
            :timeSinceLastValid => 0,
            :sensedTemperature => 0.0,
            :requestedTemperature => 0,
            :deviceTime => Time.now,
            :dayOfWeek => 0
        },
        :commandQueue => [],
        :mutex => @mutex,
    }
  end

  def monitor
    @thread = Thread.new @data do | data |
      loop do
        sleep 1
        TCPSocket.open data[:hostname], 8068 do | socket |
          mutex = data[:mutex]
          commandQueue = data[:commandQueue]
          pin = data[:pin]
          queryCommand = [0x93, 0x0B, 0x00, pin & 0xFF, pin >> 8, 0x00, 0x00, 0xFF, 0xFF]
          crc = HeatmiserCRC.new queryCommand
          queryCommand << crc.crcLo
          queryCommand << crc.crcHi
          count = 0
          loop do
            count += 1
            break if count > 15
            command = queryCommand
            fromQueue = false
            mutex.synchronize do
              fromQueue = commandQueue.size > 0
              command = commandQueue[0] if fromQueue
            end
            begin
              socket.write command.pack('c*')
              status = nil
              timeout 1 do
                status = socket.read(81).unpack('c*')
              end
              timestamp = Time.now
              crcHi = status.pop & 0xFF
              crcLo = status.pop & 0xFF
              crc = HeatmiserCRC.new status
              if (status[0] & 0xFF) == 0x94 and status[1] == 0x51 and status[2] == 0 and
                  crc.crcHi == crcHi and crc.crcLo == crcLo
                status << crcLo
                status << crcHi
                mutex.synchronize do
                  timeSinceLastValid = timestamp - data[:lastStatus][:timestamp]
                  dayOfWeek = status[51]
                  dayOfWeek = 0 if dayOfWeek == 7
                  data[:lastStatus] = {
                      :valid => true,
                      :raw => status,
                      :timestamp => timestamp,
                      :timeSinceLastValid => timeSinceLastValid,
                      :sensedTemperature => ((status[44] & 0xFF) | ((status[45] << 8) & 0x0F00)) / 10.0,
                      :requestedTemperature => status[25] & 0xFF,
                      :deviceTime => Time.utc(2000 + (status[48] & 0xFF), status[49], status[50], status[52], status[53], status[54]),
                      :dayOfWeek => dayOfWeek
                  }
                  commandQueue.shift if fromQueue
                end
                count = 0
              end
            rescue
            end
          end
        end
      end
    end.run
  end

  def lastStatus
    @mutex.synchronize do
      status = @data[:lastStatus]
      {
          :valid => status[:valid],
          :raw => status[:raw].dup,
          :timestamp => status[:timestamp],
          :timeSinceLastValid => status[:timeSinceLastValid],
          :sensedTemperature => status[:sensedTemperature],
          :requestedTemperature => status[:requestedTemperature],
          :deviceTime => status[:deviceTime],
          :dayOfWeek => status[:dayOfWeek]
      }
    end
  end

end

hm = Heatmiser.new(ARGV[0], Integer(ARGV[1]))
hm.monitor
loop do
  sleep 1
  status = hm.lastStatus
  puts "#{status[:timestamp]} #{status[:deviceTime]} #{status[:dayOfWeek]} #{status[:timeSinceLastValid]} #{status[:requestedTemperature]} #{status[:sensedTemperature]}" if status[:valid]
end
