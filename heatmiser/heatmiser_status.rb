require 'singleton'
require 'thread'
require 'trace_log'

class HeatmiserStatus

  include Singleton

  attr_reader :valid, :timestamp, :sampleTime, :timeSinceLastValid, :sensedTemperature,
      :requestedTemperature, :heatOn, :keyLockOn, :frostProtectOn, :deviceTimeOffset,
      :dayOfWeek

  @mutex = Mutex.new

  def initialize
    @log = TraceLog.instance
    @valid = false
    @raw = []
    @timestamp = Time.now
    @sampleTime = 0.0
    @timeSinceLastValid = 0.0
    @sensedTemperature = 0.0
    @requestedTemperature = 0
    @heatOn = false
    @keyLockOn = false
    @frostProtectOn = false
    @deviceTimeOffset = 0.0
    @dayOfWeek = 0
  end

  def raw
    @raw.dup
  end

  def get
    @mutex.synchronize { yield }
  end

  def set raw, timestamp, sampleTime
    @mutex.synchronize do
      @valid = true
      begin
        @raw = raw.dup
        @sensedTemperature = ((raw[44] & 0xFF) | ((raw[45] << 8) & 0x0F00)) / 10.0
        @requestedTemperature = raw[25] & 0xFF
        @heatOn = raw[47] == 1
        @keyLockOn = raw[29] == 1
        @frostProtectOn = raw[30] == 1
        @deviceTimeOffset = Time.local(2000 + (raw[48] & 0xFF), raw[49], raw[50],
                                       raw[52], raw[53], raw[54]) - timestamp
        dayOfWeek = raw[51]
        @dayOfWeek = dayOfWeek == 7 ? 0 : dayOfWeek
        @timeSinceLastValid = timestamp - @timestamp
        @timestamp = timestamp
        @sampleTime = sampleTime
        @log.info "#{(raw.collect {|byte| "%02x " % (byte & 0xFF)}).join}#{@requestedTemperature} #{@sensedTemperature} #{@heatOn} #{@keyLockOn} #{@frostProtectOn} #{@timeSinceLastValid} #{@dayOfWeek} #{@deviceTimeOffset} #{sampleTime}"
      rescue => error
        @log.error error
        @valid = false
      end
    end
  end

  def invalidate
    @mutex.synchronize { @valid = false }
  end

end
