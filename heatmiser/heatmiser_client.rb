require 'thread'
require 'socket'
require 'trace_log'
require 'heatmiser_status'
require 'command_queue'

class HeatmiserClient

  def initialize client
    @client = client
    @clientIP = client.getpeername
    @clientIP = (4 ... 8).map{|pos|@clientIP[pos]}.join('.')
  end

  def session
    Thread.new @client, @clientIP do | client, clientIP |
      status = HeatmiserStatus.instance
      log = TraceLog.instance
      log.info "client connected: #{clientIP}"
      errorCount = 0
      while errorCount < 5 do
        begin
          timeout 5 do
            command = read 5
            log.debug "header:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}" if log.debug?
            packetSize = (command[1] & 0xFF) | ((command[2] << 8) & 0x0F00)
            command += read(packetSize - 5)
            log.debug "client command:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}" if log.debug?
            CommandQueue.instance.push clientIP, command unless (command[0] & 0xFF) == 0x93
            status.get { client.write status.raw.pack('c*') if status.valid }
            errorCount = 0
          end
        rescue Timeout::Error
          errorCount += 1
        rescue => error
          log.error error
          break
        end
      end
      log.info "client disconnected: #{clientIP}"
    end
  end

  def read size
    data = @client.read size
    raise "unable to read #{size} bytes from client #{@clientIP} - presuming it has disconnected" unless data and data.size == size
    data.unpack('c*')
  end

end
