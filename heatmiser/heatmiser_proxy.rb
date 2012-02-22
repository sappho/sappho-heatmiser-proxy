require 'heatmiser_client'
require 'client_register'
require 'thread'
require 'socket'
require 'trace_log'

class HeatmiserProxy

  def serve
    Thread.new do
      clients = ClientRegister.instance
      port = Integer SystemConfiguration.instance.config['heatmiser.port']
      log = TraceLog.instance
      log.info "opening proxy server port #{port}"
      TCPServer.open port do | server |
        log.info "proxy server port #{port} is now open"
        loop do
          if clients.maxAlreadyConnected?
            sleep 1
          else
            log.info "listening for new clients on proxy server port #{port}"
            HeatmiserClient.new.session server.accept
          end
        end
      end
    end
  end

end
