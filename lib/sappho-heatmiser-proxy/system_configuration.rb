# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'singleton'
      require 'yaml'

      class SystemConfiguration

        include Singleton

        attr_reader :heatmiserId, :heatmiserHostname, :heatmiserPort, :heatmiserHardware,
                    :pinLo, :pinHi, :maxClients,
                    :mongodbHostname, :mongodbPort, :mongodbDatabase

        def initialize
          data = YAML.load_file(File.expand_path(ARGV[0] || 'heatmiser-proxy.yml'))
          @heatmiserId = data['heatmiser.id']
          @heatmiserHostname = data['heatmiser.address']
          @heatmiserPort = Integer data['heatmiser.port']
          @heatmiserHardware = data.has_key? 'heatmiser.is.hardware'
          pin = Integer data['heatmiser.pin']
          @pinLo = pin & 0xFF
          @pinHi = (pin >> 8) & 0xFF
          @maxClients = Integer data['clients.max']
          @mongodbHostname = data['mongodb.address']
          @mongodbPort = data.has_key?('mongodb.port') ? Integer(data['mongodb.port']) : 27017
          @mongodbDatabase = data['mongodb.database']
        end

      end

    end
  end
end
