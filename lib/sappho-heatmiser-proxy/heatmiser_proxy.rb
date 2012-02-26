# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'sappho-heatmiser-proxy/heatmiser_client'
      require 'sappho-heatmiser-proxy/client_register'
      require 'thread'
      require 'socket'
      require 'sappho-heatmiser-proxy/trace_log'

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

    end
  end
end
