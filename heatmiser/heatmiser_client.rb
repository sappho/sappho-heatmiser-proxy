require 'thread'
require 'socket'
require 'trace_log'
require 'heatmiser_status'
require 'command_queue'
require 'client_register'

class ReadError < Interrupt
end

class HeatmiserClient

  def session client
    @clients = ClientRegister.instance
    @clients.register client
    @ip = @clients.ip client
    @client = client
    Thread.new do
      status = HeatmiserStatus.instance
      log = TraceLog.instance
      loop do
        begin
          timeout 20 do
            command = read 5
            log.debug "header: #{TraceLog.hex command}" if log.debug?
            packetSize = (command[1] & 0xFF) | ((command[2] << 8) & 0x0F00)
            command += read(packetSize - 5)
            CommandQueue.instance.push @ip, command unless (command[0] & 0xFF) == 0x93
            status.get { @client.write status.raw.pack('c*') if status.valid }
            log.info "command received from client #{@ip} so it is alive"
          end
        rescue Timeout::Error
          log.info "no command received from client #{@ip} so presuming it dormant"
          break
        rescue ReadError
          log.info "unable to receive data from client #{@ip} so presuming it has disconnected"
          break
        rescue => error
          log.error error
          break
        end
      end
      begin
        @client.close
      rescue
      end
      @clients.unregister @client
    end
  end

  def read size
    data = @client.read size
    raise ReadError unless data and data.size == size
    data.unpack('c*')
  end

end
