require 'singleton'
require 'thread'
require 'logger'

class TraceLog

  include Singleton

  @log = Logger.new STDOUT #'heatmiser.log'
  @mutex = Mutex.new

  def initialize
    @log.level = Logger::DEBUG
    @log.formatter = proc { |severity, datetime, progname, message| "#{message}\n" }
  end

  def info message
    @mutex.synchronize do
      @log.info message
    end if @log.info?
  end

  def debug message
    @mutex.synchronize do
      @log.debug message
    end if @log.debug?
  end

  def error message
    @mutex.synchronize do
      @log.error message
    end if @log.error?
  end

  def debug?
    @log.debug?
  end

end
