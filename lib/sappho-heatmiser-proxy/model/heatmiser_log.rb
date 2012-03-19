# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Model

      require 'mongo_mapper'
      require 'mongo_mapper/document'

      class HeatmiserLog

        include MongoMapper::Document

        key :deviceId, String
        key :timestamp, Time
        key :sensedTemperature, Float
        key :requestedTemperature, Integer
        key :heatOn, Boolean
        key :frostProtectOn, Boolean
        key :deviceTimeOffset, Float

      end

    end
  end
end
