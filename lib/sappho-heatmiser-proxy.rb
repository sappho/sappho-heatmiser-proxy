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
      require 'mongo_mapper'
      require 'mongo/connection'
      require 'thread'

      class CommandLine

        def CommandLine.process
          log = Sappho::ApplicationAutoFlushLog.instance
          log.info "#{NAME} version #{VERSION} - #{HOMEPAGE}"
          config = SystemConfiguration.instance
          log.info "connecting to mongodb database #{config.mongodbDatabase} on #{config.mongodbHostname}:#{config.mongodbPort}"
          MongoMapper.connection = Mongo::Connection.new config.mongodbHostname, config.mongodbPort
          MongoMapper.database = config.mongodbDatabase
          Sappho::Socket::SafeServer.new('heatmiser proxy', config.heatmiserPort, config.maxClients, config.detailedLogging).serve do
            | socket, ip | HeatmiserClient.new(socket, ip).communicate
          end
          Thread.new do
            Heatmiser.new.monitor
          end.join
        end

      end

    end
  end
end
