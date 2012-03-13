# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'sappho-heatmiser-proxy/heatmiser_crc'
      require 'sappho-heatmiser-proxy/heatmiser_status'
      require 'sappho-heatmiser-proxy/trace_log'
      require 'sappho-heatmiser-proxy/command_queue'
      require 'sappho-heatmiser-proxy/system_configuration'
      require 'timeout'
      require 'socket'

      class Heatmiser

        def monitor
          status = HeatmiserStatus.instance
          queue = CommandQueue.instance
          log = TraceLog.instance
          config = SystemConfiguration.instance
          desc = "heatmiser at #{config.heatmiserHostname}:#{config.heatmiserPort}"
          queryCommand = HeatmiserCRC.new([0x93, 0x0B, 0x00, config.pinLo, config.pinHi, 0x00, 0x00, 0xFF, 0xFF]).appendCRC
          loop do
            log.info "opening connection to #{desc}"
            socket = nil
            begin
              timeout 5 do
                socket = TCPSocket.open config.heatmiserHostname, config.heatmiserPort
              end
              log.info "connected to #{desc}"
            rescue Timeout::Error
              log.info "timeout while connecting to #{desc}"
            rescue => error
              log.error error
            end
            if socket
              active = true
              while active do
                begin
                  sleep 5
                  command = queryCommand
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
                  log.info "#{desc} is not responding - assuming connection down"
                  active = false
                rescue => error
                  log.error error
                  active = false
                end
              end
              status.invalidate
              begin
                socket.close
              rescue
              end
              log.info "closed connection to #{desc}"
            end
            log.info "waiting 10 seconds before attempting to re-connect to #{desc}"
            sleep 10
          end
        end

      end

    end
  end
end
