# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'socket'
      require 'sappho-heatmiser-proxy/trace_log'
      require 'sappho-heatmiser-proxy/heatmiser_status'
      require 'sappho-heatmiser-proxy/command_queue'
      require 'sappho-heatmiser-proxy/client_register'

      class HeatmiserClient

        def initialize client
          @clients = ClientRegister.instance
          @clients.register client
          @ip = @clients.ip client
          @client = client
          @status = HeatmiserStatus.instance
          @log = TraceLog.instance
        end

        def communicate
          loop do
            begin
              timeout 20 do
                command = read 5
                if command == 'check'
                  reply = @status.get {
                    @status.timeSinceLastValid > 60 ?
                        'error: no response from heatmiser unit in last minute' :
                        @status.valid ? 'ok' : 'error: last response from heatmiser unit was invalid'
                  }
                  @log.info "client requested status - reply: #{reply}"
                  @client.writeline reply
                else
                  @log.debug "header: #{TraceLog.hex command}" if @log.debug?
                  packetSize = (command[1] & 0xFF) | ((command[2] << 8) & 0x0F00)
                  command += read(packetSize - 5)
                  CommandQueue.instance.push @ip, command unless (command[0] & 0xFF) == 0x93
                  @status.get { @client.write @status.raw.pack('c*') if @status.valid }
                  @log.info "command received from client #{@ip} so it is alive"
                end
              end
            rescue Timeout::Error
              @log.info "no command received from client #{@ip} so presuming it dormant"
              break
            rescue HeatmiserClient::ReadError
              @log.info "unable to receive data from client #{@ip} so presuming it has disconnected"
              break
            rescue => error
              @log.error error
              break
            end
          end
          begin
            @client.close
          rescue
          end
          @clients.unregister @client
        end

        def read size
          data = @client.read size
          raise HeatmiserClient::ReadError unless data and data.size == size
          data.unpack('c*')
        end

        class ReadError < Interrupt
        end

      end

    end
  end
end
