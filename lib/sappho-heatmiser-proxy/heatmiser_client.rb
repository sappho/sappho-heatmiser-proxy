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
      require 'sappho-heatmiser-proxy/system_configuration'

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
          config = SystemConfiguration.instance
          active = true
          while active do
            begin
              timeout 20 do
                command = read 5
                if command == 'check'
                  reply = @status.get {
                    @status.timeSinceLastValid > 60 ?
                        'error: no response from heatmiser unit in last minute' :
                        @status.valid ? 'ok' : 'error: last response from heatmiser unit was invalid'
                  }
                  @log.info "client #{@ip} checking status - reply: #{reply}"
                  @client.write "#{reply}\r\n"
                  active = false
                else
                  command = command.unpack('c*')
                  @log.debug "header: #{TraceLog.hex command}" if @log.debug?
                  raise ClientDataError, "invalid pin" unless (command[3] & 0xFF) == config.pinLo and (command[4] & 0xFF) == config.pinHi
                  packetSize = (command[1] & 0xFF) | ((command[2] << 8) & 0xFF00)
                  raise ClientDataError, "invalid packet size" if packetSize < 7 or packetSize > 128
                  command += read(packetSize - 5).unpack('c*')
                  CommandQueue.instance.push @ip, command unless (command[0] & 0xFF) == 0x93
                  @status.get { @client.write @status.raw.pack('c*') if @status.valid }
                  @log.info "command received from client #{@ip} so it is alive"
                end
              end
            rescue Timeout::Error
              @log.info "timeout on client #{@ip} so presuming it dormant"
              active = false
            rescue ClientDataError => error
              @log.info "data error from client #{@ip}: #{error.message}"
              active = false
            rescue => error
              @log.error error
              active = false
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
          raise ClientDataError, "nothing received so presuming it has disconnected" unless data and data.size == size
          data
        end

        class ClientDataError < Interrupt
        end

      end

    end
  end
end
