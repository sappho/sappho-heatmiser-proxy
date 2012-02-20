require 'singleton'
require 'heatmiser_crc'
require 'heatmiser_status'
require 'trace_log'
require 'command_queue'
require 'thread'
require 'timeout'
require 'socket'
require 'logger'
require 'yaml'

class Heatmiser

  include Singleton

  def initialize
    config = YAML.load_file 'heatmiser.yml'
    @hostname = config['hostname']
    @pin = Integer config['pin']
  end

  def monitor
    @thread = Thread.new @hostname, @pin do | hostname, pin |
      status = HeatmiserStatus.instance
      queue = CommandQueue.instance
      log = TraceLog.instance
      port = 8068
      pinLo = pin & 0xFF
      pinHi = (pin >> 8) & 0xFF
      queryCommand = HeatmiserCRC.new([0x93, 0x0B, 0x00, pinLo, pinHi, 0x00, 0x00, 0xFF, 0xFF]).appendCRC
      loop do
        status.invalidate
        log.info "opening connection to heatmiser at #{hostname}:#{port}"
        TCPSocket.open hostname, port do | socket |
          log.info "connected to heatmiser at #{hostname}:#{port}"
          errorCount = 0
          while errorCount < 10 do
            begin
              errorCount += 1
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
                  log.info "clock correction:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}"
                end
              end
              log.debug "sending command:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}" if log.debug?
              reply = []
              startTime = Time.now
              timeout 5 do
                socket.write command.pack('c*')
                reply = socket.read(81).unpack('c*')
              end
              timestamp = Time.now
              log.debug "reply:#{(reply.collect {|byte| " %02x" % (byte & 0xFF)}).join}" if log.debug?
              crcHi = reply.pop & 0xFF
              crcLo = reply.pop & 0xFF
              crc = HeatmiserCRC.new reply
              if (reply[0] & 0xFF) == 0x94 and reply[1] == 0x51 and reply[2] == 0 and
                  crc.crcHi == crcHi and crc.crcLo == crcLo
                reply << crcLo << crcHi
                status.set reply, timestamp, (timestamp - startTime)
                queue.completed if queuedCommand
                errorCount = 0
              end
            rescue => error
              log.error error.message
              log.error error.backtrace
            end
          end
          log.info "closing connection to heatmiser at #{hostname}:#{port}"
          socket.close
          sleep 5
        end
      end
    end
  end

  def wait
    @thread.join
  end

end
