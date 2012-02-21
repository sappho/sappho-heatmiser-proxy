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
      log.info "client #{clientIP} connected"
      loop do
        begin
          timeout 10 do
            command = read 5
            log.debug "header: #{TraceLog.hex command}" if log.debug?
            packetSize = (command[1] & 0xFF) | ((command[2] << 8) & 0x0F00)
            command += read(packetSize - 5)
            CommandQueue.instance.push clientIP, command unless (command[0] & 0xFF) == 0x93
            status.get { client.write status.raw.pack('c*') if status.valid }
          end
        rescue Timeout::Error
          log.info "no command received from client #{clientIP} which might be dormant"
          break
        rescue => error
          log.error error
          break
        end
      end
      client.close
      log.info "client #{clientIP} disconnected"
    end
  end

  def read size
    data = @client.read size
    raise "unable to read #{size} bytes from client #{@clientIP} - presuming it has disconnected" unless data and data.size == size
    data.unpack('c*')
  end

end
