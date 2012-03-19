# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'singleton'
      require 'thread'
      require 'sappho-basics/auto_flush_log'

      class HeatmiserStatus

        include Singleton, Sappho::LogUtilities

        attr_reader :valid, :timestamp, :sampleTime, :timeSinceLastValid, :sensedTemperature,
            :requestedTemperature, :heatOn, :keyLockOn, :frostProtectOn, :deviceTimeOffset,
            :dayOfWeek, :schedule

        class TimedTemperature

          attr_reader :hour, :minute, :temperature

          def initialize raw, bytePosition
            @hour = raw[bytePosition] & 0xFF
            @minute = raw[bytePosition + 1] & 0xFF
            @temperature = raw[bytePosition + 2] & 0xFF
          end

          def valid?
            @hour < 24 and @minute < 60
          end

          def description
            "#{@hour}:#{@minute}-#{@temperature}"
          end

        end

        class Schedule

          attr_reader :schedule

          def initialize raw, bytePosition
            @schedule = []
            (0 ... 4).map do |position|
              timedTemperature = TimedTemperature.new(raw, bytePosition + 3 * position)
              @schedule << timedTemperature if timedTemperature.valid?
            end
          end

          def description
            (@schedule.collect {|timedTemperature| timedTemperature.description}).join(' ')
          end

        end

        def initialize
          @mutex = Mutex.new
          @log = Sappho::ApplicationAutoFlushLog.instance
          @valid = false
          @raw = []
          @timestamp = Time.now
          @sampleTime = 0.0
          @timeSinceLastValid = 0.0
          @sensedTemperature = 0.0
          @requestedTemperature = 0
          @holidayReturnTime = Time.now
          @holdMinutes = 0
          @heatOn = false
          @keyLockOn = false
          @frostProtectOn = false
          @holidayOn = false
          @deviceTimeOffset = 0.0
          @dayOfWeek = 0
          @schedule = {}
        end

        def raw
          @raw.dup
        end

        def get
          @mutex.synchronize { yield }
        end

        def set raw, timestamp, sampleTime
          @mutex.synchronize do
            @valid = false
            @raw = raw.dup
            @sensedTemperature = ((raw[44] & 0xFF) | ((raw[45] << 8) & 0xFF00)) / 10.0
            @holdMinutes = (raw[38] & 0xFF) | ((raw[39] << 8) & 0xFF00)
            @heatOn = raw[47] == 1
            @keyLockOn = raw[29] == 1
            @frostProtectOn = raw[30] == 1
            @holidayOn = raw[37] == 1
            @holidayReturnTime = Time.local(2000 + (raw[32] & 0xFF), raw[33], raw[34], raw[35], raw[36], 0)
            @requestedTemperature = @frostProtectOn ? raw[24] & 0xFF : raw[25] & 0xFF
            @deviceTimeOffset = Time.local(2000 + (raw[48] & 0xFF), raw[49], raw[50],
                                           raw[52], raw[53], raw[54]) - timestamp
            dayOfWeek = raw[51]
            @dayOfWeek = dayOfWeek == 7 ? 0 : dayOfWeek
            @schedule = {
                :weekday => Schedule.new(@raw, 55),
                :weekend => Schedule.new(@raw, 67)
            }
            @timeSinceLastValid = timestamp - @timestamp
            @timestamp = timestamp
            @sampleTime = sampleTime
            @valid = true
            if @log.debug?
              @log.debug "#{hexString raw}"
              @log.debug "#{@requestedTemperature} #{@holdMinutes / 60}:#{@holdMinutes % 60} #{@sensedTemperature} #{@heatOn} #{@keyLockOn} #{@frostProtectOn} #{@timeSinceLastValid} #{@dayOfWeek} #{@deviceTimeOffset} #{sampleTime} #{@holidayOn} #{@holidayReturnTime}"
              @log.debug "weekday: #{@schedule[:weekday].description} weekend: #{@schedule[:weekend].description}"
            else
              @log.info "received status: heating is #{@heatOn ? "on" : "off"} because required temperature is #{@requestedTemperature} and actual is #{@sensedTemperature}"
            end
          end
        end

        def invalidate
          @mutex.synchronize { @valid = false }
        end

      end

    end
  end
end
