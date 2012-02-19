require 'heatmiser_crc'
require 'thread'
require 'timeout'
require 'socket'
require 'logger'

class HeatmiserProxy

  def initialize heatmiser
    @heatmiser = heatmiser
  end

  def monitor
    Thread.new @heatmiser do | heatmiser |
      log = Logger.new STDOUT
      log.level = Logger::DEBUG
      log.formatter = proc { |severity, datetime, progname, msg| "#{msg}\n" }
      port = 8068
      log.info "opening port #{port}"
      TCPServer.open port do | server |
        log.info 'port open'
        loop do
          log.info 'listening for clients'
          client = server.accept
          log.info 'client connected'
          Thread.new client, heatmiser, log do | client, heatmiser, log |
            loop do
              begin
                timeout 5 do
                  header = client.read(5).unpack('c*')
                  log.debug "header:#{(header.collect {|byte| " %02x" % (byte & 0xFF)}).join}" if log.debug?
                  packetSize = (header[1] & 0xFF) | ((header[2] << 8) & 0x0F00)
                  packet = client.read(packetSize - 5).unpack('c*')
                  log.debug "packet:#{((header + packet).collect {|byte| " %02x" % (byte & 0xFF)}).join}" if log.debug?
                  unless (header[0] & 0xFF) == 0x93

                  end
                  status = heatmiser.lastStatus
                  if status[:valid]
                    log.debug "status:#{(status[:raw].collect {|byte| " %02x" % (byte & 0xFF)}).join}" if log.debug?
                    client.write status[:raw].pack('c*')
                  end
                end
              rescue Timeout::Error
                # just wait for something to come in
              rescue => error
                log.error error.message
                log.error error.backtrace
                break
              end
            end
            log.info 'client disconnected'
          end
        end
      end
    end
  end

end
