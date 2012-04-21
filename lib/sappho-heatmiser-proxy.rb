# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'sappho-heatmiser-proxy/heatmiser'
      require 'sappho-heatmiser-proxy/heatmiser_client'
      require 'sappho-basics/auto_flush_log'
      require 'sappho-socket/safe_server'
      require 'sappho-heatmiser-proxy/version'
      require 'thread'

      class CommandLine

        def CommandLine.process
          Sappho::ApplicationAutoFlushLog.instance.info "#{NAME} version #{VERSION} - #{HOMEPAGE}"
          port = SystemConfiguration.instance.heatmiserPort
          maxClients = SystemConfiguration.instance.maxClients
          server = Sappho::Socket::SafeServer.new('heatmiser proxy', port, maxClients, 15, true)
          server.serve do
            | socket, ip | HeatmiserClient.new(socket, ip).communicate
          end
          Thread.new do
            Heatmiser.new.monitor { server.clientCount > 0 }
          end.join
        end

      end

    end
  end
end
