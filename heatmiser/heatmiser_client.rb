require 'thread'
require 'socket'
require 'trace_log'
require 'heatmiser'
require 'heatmiser_status'
require 'command_queue'

class HeatmiserClient

  def initialize client
    @client = client
  end

  def session
    Thread.new @client do | client |
      heatmiser = Heatmiser.instance
      status = HeatmiserStatus.instance
      log = TraceLog.instance
      peer = client.getpeername
      peer = (4 ... 8).map{|pos|peer[pos]}.join('.')
      log.info "client connected: #{peer}"
      errorCount = 0
      while errorCount < 5 do
        begin
          timeout 5 do
            header = client.read(5).unpack('c*')
            log.debug "header:#{(header.collect {|byte| " %02x" % (byte & 0xFF)}).join}" if log.debug?
            packetSize = (header[1] & 0xFF) | ((header[2] << 8) & 0x0F00)
            command = header + client.read(packetSize - 5).unpack('c*')
            log.debug "client command:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}" if log.debug?
            CommandQueue.push peer, command unless (command[0] & 0xFF) == 0x93
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
      log.info "client disconnected: #{peer}"
    end
  end

end