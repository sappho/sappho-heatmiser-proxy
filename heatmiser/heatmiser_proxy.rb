require 'heatmiser_client'
require 'client_register'
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
        clients = ClientRegister.instance
        loop do
          log.info "listening for new clients on proxy server port #{port}"
          client = server.accept
          begin
            clients.put client
            HeatmiserClient.new.session client
          rescue => error
            log.error error
          end
          clients.close client
        end
      end
    end
  end

end
