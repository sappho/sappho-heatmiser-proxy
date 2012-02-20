require 'heatmiser_client'
require 'thread'
require 'socket'
require 'trace_log'

class HeatmiserProxy

  def serve
    Thread.new do
      port = 8068
      log = TraceLog.instance
      log.info "opening server port #{port}"
      TCPServer.open port do | server |
        log.info "server port #{port} is now open"
        loop do
          log.info "listening for new clients on port #{port}"
          HeatmiserClient.new(server.accept).session
        end
      end
    end
  end

end
