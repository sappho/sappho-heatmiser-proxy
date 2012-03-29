# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'sappho-heatmiser-proxy/heatmiser_crc'
      require 'sappho-heatmiser-proxy/heatmiser_status'
      require 'sappho-basics/auto_flush_log'
      require 'sappho-heatmiser-proxy/command_queue'
      require 'sappho-heatmiser-proxy/system_configuration'
      require 'sappho-socket/safe_socket'

      class Heatmiser

        include Sappho::LogUtilities

        def monitor
          status = HeatmiserStatus.instance
          queue = CommandQueue.instance
          log = Sappho::ApplicationAutoFlushLog.instance
          config = SystemConfiguration.instance
          desc = "heatmiser at #{config.heatmiserHostname}:#{config.heatmiserPort}"
          queryCommand = HeatmiserCRC.new([0x93, 0x0B, 0x00, config.pinLo, config.pinHi, 0x00, 0x00, 0xFF, 0xFF]).appendCRC
          socket = Sappho::Socket::SafeSocket.new 5
          timestamp = Time.now - config.sampleDelay
          loop do
            begin
              command = nil
              if queuedCommand = queue.get
                command = queuedCommand
              else
                if status.get{status.valid ? status.deviceTimeOffset : 0.0}.abs > 150
                  timeNow = Time.now
                  dayOfWeek = timeNow.wday
                  dayOfWeek = 7 if dayOfWeek == 0
                  command = HeatmiserCRC.new([0xA3, 0x12, 0x00, config.pinLo, config.pinHi, 0x01, 0x2B, 0x00, 0x07,
                                             timeNow.year - 2000,
                                             timeNow.month,
                                             timeNow.day,
                                             dayOfWeek,
                                             timeNow.hour,
                                             timeNow.min,
                                             timeNow.sec]).appendCRC
                  log.info "clock correction: #{hexString command}"
                end
              end
              unless command
                command = queryCommand if (Time.now - timestamp) >= config.sampleDelay
              end
              if command
                log.debug "sending command: #{hexString command}" if log.debug?
                socket.close #  just in case it wasn't last time around
                socket.open config.heatmiserHostname, config.heatmiserPort
                socket.settle 0.1
                startTime = Time.now
                socket.write command.pack('c*')
                reply = socket.read(81).unpack('c*')
                timestamp = Time.now
                socket.settle 0.1
                socket.close
                log.debug "reply: #{hexString reply}" if log.debug?
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
              end
            rescue Timeout::Error
              status.invalidate
              log.info "#{desc} is not responding - assuming connection down"
            rescue => error
              status.invalidate
              log.error error
            end
            socket.settle 2
          end
        end

      end

    end
  end
end
