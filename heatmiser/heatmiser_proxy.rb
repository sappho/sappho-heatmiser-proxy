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
    log = Logger.new 'server.log'
    log.level = Logger::INFO
    log.formatter = proc { |severity, datetime, progname, msg| "#{msg}\n" }
    port = 8068
    mutex = Mutex.new
    Thread.new @heatmiser, log, port, mutex do | heatmiser, log, port, mutex |
      log.info "opening port #{port}"
      TCPServer.open port do | server |
        log.info 'port open'
        loop do
          log.info 'listening for clients'
          client = server.accept
          Thread.new client, heatmiser, log, mutex do | client, heatmiser, log, mutex |
            peer = client.getpeername
            peer = (4 ... 8).map{|pos| peer[pos]}.join('.')
            log.info "client connected: #{peer}"
            clientLog = Logger.new "client-#{peer}.log"
            clientLog.level = Logger::INFO
            clientLog.formatter = proc { |severity, datetime, progname, msg| "#{msg}\n" }
            errorCount = 0
            while errorCount < 10 do
              begin
                timeout 5 do
                  header = client.read(5).unpack('c*')
                  clientLog.debug "header:#{(header.collect {|byte| " %02x" % (byte & 0xFF)}).join}" if clientLog.debug?
                  packetSize = (header[1] & 0xFF) | ((header[2] << 8) & 0x0F00)
                  command = header + client.read(packetSize - 5).unpack('c*')
                  clientLog.debug "command:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}" if clientLog.debug?
                  unless (command[0] & 0xFF) == 0x93
                    clientLog.info "command:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}"
                    heatmiser.queueCommand command
                  end
                  status = heatmiser.lastStatus
                  if status[:valid]
                    clientLog.debug "status:#{(status[:raw].collect {|byte| " %02x" % (byte & 0xFF)}).join}" if clientLog.debug?
                    client.write status[:raw].pack('c*')
                  end
                  errorCount = 0
                end
              rescue Timeout::Error
                errorCount += 1
              rescue => error
                clientLog.error error.message
                clientLog.error error.backtrace
                errorCount = 10
              end
            end
            log.info "client disconnected: #{peer}"
          end
        end
      end
    end
  end

end
