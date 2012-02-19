require 'heatmiser_crc'
require 'thread'
require 'timeout'
require 'socket'
require 'logger'

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
            :frostProtectOn => false,
            :deviceTimeOffset => 0.0,
            :dayOfWeek => 0
        },
        :commandQueue => [],
        :mutex => @mutex
    }
  end

  def monitor
    @thread = Thread.new @data do | data |
      log = Logger.new 'heatmiser.log'
      log.level = Logger::INFO
      log.formatter = proc { |severity, datetime, progname, msg| "#{msg}\n" }
      mutex = data[:mutex]
      commandQueue = data[:commandQueue]
      hostname = data[:hostname]
      port = 8068
      pin = data[:pin]
      pinLo = pin & 0xFF
      pinHi = (pin >> 8) & 0xFF
      queryCommand = HeatmiserCRC.new(
          [0x93, 0x0B, 0x00, pinLo, pinHi, 0x00, 0x00, 0xFF, 0xFF]).appendCRC
      loop do
        mutex.synchronize do
          data[:lastStatus][:valid] = false
        end
        log.info "opening connection to heatmiser at #{hostname}:#{port}"
        TCPSocket.open hostname, port do | socket |
          log.info 'connected'
          deviceTimeOffset = 0.0
          errorCount = 0
          while errorCount < 10 do
            errorCount += 1
            sleep 5
            command = queryCommand
            fromQueue = false
            mutex.synchronize do
              fromQueue = commandQueue.size > 0
              command = commandQueue[0][:command].dup if fromQueue
            end
            if fromQueue
              log.info "requested command:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}"
            else
              if deviceTimeOffset.abs > 5.0
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
                log.info "clock correction:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}"
              end
            end
            begin
              log.debug "command:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}" if log.debug?
              socket.write command.pack('c*')
              status = nil
              timeout 5 do
                status = socket.read(81).unpack('c*')
                log.debug "status:#{(status.collect {|byte| " %02x" % (byte & 0xFF)}).join}" if log.debug?
              end
              timestamp = Time.now
              crcHi = status.pop & 0xFF
              crcLo = status.pop & 0xFF
              crc = HeatmiserCRC.new status
              if (status[0] & 0xFF) == 0x94 and status[1] == 0x51 and status[2] == 0 and
                  crc.crcHi == crcHi and crc.crcLo == crcLo
                status << crcLo << crcHi
                timeSinceLastValid = timestamp - data[:lastStatus][:timestamp]
                dayOfWeek = status[51]
                dayOfWeek = 0 if dayOfWeek == 7
                deviceTimeOffset = Time.local(2000 + (status[48] & 0xFF), status[49], status[50],
                                              status[52], status[53], status[54]) - timestamp
                requestedTemperature = status[25] & 0xFF
                sensedTemperature = ((status[44] & 0xFF) | ((status[45] << 8) & 0x0F00)) / 10.0
                heatOn = status[47] == 1
                keyLockOn = status[29] == 1
                frostProtectOn = status[30] == 1
                log.info "#{(status.collect {|byte| "%02x " % (byte & 0xFF)}).join}#{requestedTemperature} #{sensedTemperature} #{heatOn} #{keyLockOn} #{frostProtectOn} #{timeSinceLastValid} #{dayOfWeek} #{deviceTimeOffset}"
                mutex.synchronize do
                  data[:lastStatus] = {
                      :valid => true,
                      :raw => status,
                      :timestamp => timestamp,
                      :timeSinceLastValid => timeSinceLastValid,
                      :sensedTemperature => sensedTemperature,
                      :requestedTemperature => requestedTemperature,
                      :heatOn => heatOn,
                      :keyLockOn => keyLockOn,
                      :frostProtectOn => frostProtectOn,
                      :deviceTimeOffset => deviceTimeOffset,
                      :dayOfWeek => dayOfWeek
                  }
                  commandQueue.shift if fromQueue
                end
                errorCount = 0
              end
            rescue => error
              log.error error.message
              log.error error.backtrace
            end
          end
          log.info 'closing connection to heatmiser'
          socket.close
          sleep 5
        end
      end
    end
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
          :frostProtectOn => status[:frostProtectOn],
          :deviceTimeOffset => status[:deviceTimeOffset],
          :dayOfWeek => status[:dayOfWeek]
      }
    end
  end

  def pin
    @data[:pin]
  end

  def mutex
    @mutex
  end

  def wait
    @thread.join
  end

end
