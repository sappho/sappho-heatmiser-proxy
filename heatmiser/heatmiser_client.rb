require 'thread'
require 'socket'
require 'trace_log'
require 'heatmiser_status'
require 'command_queue'

class HeatmiserClient

  def session client
    @client = client
    @ip = ClientRegister.instance.ip client
    Thread.new do
      status = HeatmiserStatus.instance
      log = TraceLog.instance
      loop do
        begin
          timeout 15 do
            command = read 5
            log.debug "header: #{TraceLog.hex command}" if log.debug?
            packetSize = (command[1] & 0xFF) | ((command[2] << 8) & 0x0F00)
            command += read(packetSize - 5)
            CommandQueue.instance.push @ip, command unless (command[0] & 0xFF) == 0x93
            status.get { @client.write status.raw.pack('c*') if status.valid }
            log.info "command received from client #{@ip} so it is alive"
          end
        rescue Timeout::Error
          log.info "no command received from client #{@ip} which might be dormant"
          break
        rescue => error
          log.error error
          break
        end
      end
    end
  end

  def read size
    data = @client.read size
    raise "unable to read #{size} bytes from client #{@ip} - presuming it has disconnected" unless data and data.size == size
    data.unpack('c*')
  end

end
