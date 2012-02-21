require 'heatmiser_client'
require 'thread'
require 'socket'
require 'trace_log'

class HeatmiserProxy

  def serve
    Thread.new do
      port = Integer SystemConfiguration.instance.config['heatmiser.port']
      log = TraceLog.instance
      log.info "opening proxy server port #{port}"
      TCPServer.open port do | server |
        log.info "proxy server port #{port} is now open"
        loop do
          log.info "listening for new clients on proxy server port #{port}"
          HeatmiserClient.new(server.accept).session
        end
      end
    end
  end

end
