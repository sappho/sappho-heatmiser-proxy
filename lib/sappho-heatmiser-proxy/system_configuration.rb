# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'singleton'
      require 'yaml'
      require 'sappho-basics/auto_flush_log'

      class SystemConfiguration

        include Singleton

        attr_reader :heatmiserId, :heatmiserHostname, :heatmiserPort, :heatmiserHardware,
                    :pinLo, :pinHi, :maxClients,
                    :mongoLogging, :mongodbHostname, :mongodbPort, :mongodbDatabase,
                    :detailedLogging

        def initialize
          log = Sappho::ApplicationAutoFlushLog.instance
          filename = File.expand_path(ARGV[0] || 'heatmiser-proxy.yml')
          log.info "loading application configuration from #{filename}"
          data = YAML.load_file(filename)
          @heatmiserId = data['heatmiser.id']
          @heatmiserHostname = data['heatmiser.address']
          @heatmiserPort = data.has_key?('heatmiser.port') ? Integer(data['heatmiser.port']) : 8068
          @heatmiserHardware = data.has_key? 'heatmiser.hardware'
          pin = Integer data['heatmiser.pin']
          @pinLo = pin & 0xFF
          @pinHi = (pin >> 8) & 0xFF
          @maxClients = data.has_key?('clients.max') ? Integer(data['clients.max']) : 10
          @mongoLogging = data.has_key?('mongodb.address') and data.has_key?('mongodb.database')
          @mongodbHostname = data['mongodb.address']
          @mongodbPort = data.has_key?('mongodb.port') ? Integer(data['mongodb.port']) : 27017
          @mongodbDatabase = data['mongodb.database']
          @detailedLogging = data.has_key? 'logging.detailed'
          raise "missing settings in #{filename}" unless @heatmiserId and @heatmiserHostname
        end

      end

    end
  end
end
