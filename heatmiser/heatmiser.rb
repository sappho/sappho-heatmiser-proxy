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
            :heatOn => false,
            :keyLockOn => false,
            :deviceTimeOffset => 0.0,
            :dayOfWeek => 0
        },
        :commandQueue => [],
        :mutex => @mutex,
    }
  end

  def monitor
    @thread = Thread.new @data do | data |
      mutex = data[:mutex]
      commandQueue = data[:commandQueue]
      pin = data[:pin]
      pinLo = pin & 0xFF
      pinHi = (pin >> 8) & 0xFF
      loop do
        mutex.synchronize do
          data[:lastStatus][:valid] = false
        end
        TCPSocket.open data[:hostname], 8068 do | socket |
          queryCommand = HeatmiserCRC.new(
              [0x93, 0x0B, 0x00, pinLo, pinHi, 0x00, 0x00, 0xFF, 0xFF]).appendCRC
          deviceTimeOffset = 0.0
          errorCount = 0
          while errorCount < 10 do
            errorCount += 1
            sleep 5
            command = queryCommand
            fromQueue = false
            mutex.synchronize do
              fromQueue = commandQueue.size > 0
              command = commandQueue[0] if fromQueue
            end
            if !fromQueue and deviceTimeOffset.abs > 30.0
              timeNow = Time.now
              dayOfWeek = timeNow.wday
              dayOfWeek = 7 if dayOfWeek == 0
              command = HeatmiserCRC.new([0xA3, 0x12, 0x00, pinLo, pinHi, 0x01, 0x2B, 0x00, 0x07,
                                         timeNow.year - 2000,
                                         timeNow.month,
                                         timeNow.day,
                                         dayOfWeek,
                                         timeNow.hour,
                                         timeNow.min,
                                         timeNow.sec]).appendCRC
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
                status << crcLo << crcHi
                mutex.synchronize do
                  timeSinceLastValid = timestamp - data[:lastStatus][:timestamp]
                  dayOfWeek = status[51]
                  dayOfWeek = 0 if dayOfWeek == 7
                  deviceTimeOffset = Time.local(2000 + (status[48] & 0xFF), status[49], status[50],
                                                status[52], status[53], status[54]) - timestamp
                  data[:lastStatus] = {
                      :valid => true,
                      :raw => status,
                      :timestamp => timestamp,
                      :timeSinceLastValid => timeSinceLastValid,
                      :sensedTemperature => ((status[44] & 0xFF) | ((status[45] << 8) & 0x0F00)) / 10.0,
                      :requestedTemperature => status[25] & 0xFF,
                      :heatOn => status[47] == 1,
                      :keyLockOn => status[29] == 1,
                      :deviceTimeOffset => deviceTimeOffset,
                      :dayOfWeek => dayOfWeek
                  }
                  commandQueue.shift if fromQueue
                end
                errorCount = 0
              end
            rescue
            end
          end
          socket.close
        end
        sleep 5
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
          :heatOn => status[:heatOn],
          :keyLockOn => status[:keyLockOn],
          :deviceTimeOffset => status[:deviceTimeOffset],
          :dayOfWeek => status[:dayOfWeek]
      }
    end
  end

end

hm = Heatmiser.new(ARGV[0], Integer(ARGV[1]))
hm.monitor
loop do
  sleep 5
  status = hm.lastStatus
  puts "#{(status[:raw].collect {|byte| "%02x " % (byte & 0xFF)}).join}#{status[:requestedTemperature]} #{status[:sensedTemperature]} #{status[:heatOn]} #{status[:keyLockOn]} #{status[:timestamp]} #{status[:dayOfWeek]} #{status[:deviceTimeOffset]}" if status[:valid]
end
