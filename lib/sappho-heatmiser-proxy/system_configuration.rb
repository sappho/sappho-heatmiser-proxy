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

        attr_reader :heatmiserHostname, :heatmiserPort, :pinLo, :pinHi, :maxClients

        def initialize
          data = YAML.load_file(File.expand_path(ARGV[0] || 'heatmiser-proxy.yml'))
          @heatmiserHostname = data['heatmiser.address']
          @heatmiserPort = Integer data['heatmiser.port']
          pin = Integer data['heatmiser.pin']
          @pinLo = pin & 0xFF
          @pinHi = (pin >> 8) & 0xFF
          @maxClients = Integer data['clients.max']
        end

      end

    end
  end
end
