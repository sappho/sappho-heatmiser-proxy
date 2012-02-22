require 'heatmiser_crc'
require 'heatmiser_status'
require 'trace_log'
require 'command_queue'
require 'thread'
require 'timeout'
require 'socket'
require 'system_configuration'

class Heatmiser

  def monitor
    @thread = Thread.new do
      status = HeatmiserStatus.instance
      queue = CommandQueue.instance
      log = TraceLog.instance
      config = SystemConfiguration.instance.config
      hostname = config['heatmiser.address']
      port = Integer config['heatmiser.port']
      pin = Integer config['heatmiser.pin']
      pinLo = pin & 0xFF
      pinHi = (pin >> 8) & 0xFF
      queryCommand = HeatmiserCRC.new([0x93, 0x0B, 0x00, pinLo, pinHi, 0x00, 0x00, 0xFF, 0xFF]).appendCRC
      loop do
        status.invalidate
        begin
          log.info "opening connection to heatmiser at #{hostname}:#{port}"
          TCPSocket.open hostname, port do | socket |
            log.info "connected to heatmiser at #{hostname}:#{port}"
            loop do
              begin
                sleep 5
                command = queryCommand
                if queuedCommand = queue.get
                  command = queuedCommand
                else
                  if status.get{status.deviceTimeOffset}.abs > 5.0
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
                    log.info "clock correction: #{TraceLog.hex command}"
                  end
                end
                log.debug "sending command: #{TraceLog.hex command}" if log.debug?
                reply = []
                startTime = Time.now
                timeout 20 do
                  socket.write command.pack('c*')
                  reply = socket.read(81).unpack('c*')
                end
                timestamp = Time.now
                log.debug "reply: #{TraceLog.hex reply}" if log.debug?
                crcHi = reply.pop & 0xFF
                crcLo = reply.pop & 0xFF
                crc = HeatmiserCRC.new reply
                if (reply[0] & 0xFF) == 0x94 and reply[1] == 0x51 and reply[2] == 0 and
                    crc.crcHi == crcHi and crc.crcLo == crcLo
                  reply << crcLo << crcHi
                  status.set reply, timestamp, (timestamp - startTime) do
                    queue.completed if queuedCommand
                  end
                end
              rescue Timeout::Error
                log.info "heatmiser at #{hostname}:#{port} is not responding - assuming connection down"
                break
              rescue => error
                log.error error
                break
              end
            end
            log.info "closing connection to heatmiser at #{hostname}:#{port}"
            socket.close
          end
        rescue => error
          log.error error
        end
        sleep 10
      end
    end
  end

  def wait
    @thread.join
  end

end
