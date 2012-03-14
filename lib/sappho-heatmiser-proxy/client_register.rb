# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'singleton'
      require 'thread'
      require 'sappho-socket/auto_flush_log'
      require 'sappho-heatmiser-proxy/system_configuration'

      class ClientRegister

        include Singleton

        def initialize
          @log = Sappho::Socket::AutoFlushLog.instance
          @mutex = Mutex.new
          @clients = {}
        end

        def register client
          @mutex.synchronize do
            ip = client.getpeername
            @clients[client] = ip = (4 ... 8).map{|pos|ip[pos]}.join('.')
            @log.info "client #{ip} connected"
            log
          end
        end

        def unregister client
          @mutex.synchronize do
            ip = @clients[client]
            @clients.delete client
            @log.info "client #{ip} disconnected"
            log
          end
        end

        def ip client
          @mutex.synchronize { @clients[client] }
        end

        def maxAlreadyConnected?
          @mutex.synchronize { @clients.size >= SystemConfiguration.instance.maxClients }
        end

        private

        def log
          @log.info "clients: #{@clients.size > 0 ?
              (@clients.collect{|client, ip| ip}).join(', ') : 'none'}"
        end

      end

    end
  end
end
