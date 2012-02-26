require 'singleton'
require 'thread'
require 'logger'
require 'system_configuration'

class TraceLog

  include Singleton

  def initialize
    @mutex = Mutex.new
    config = SystemConfiguration.instance.config
    @log = Logger.new(config['log.stdout'] ? STDOUT : config['log.filename'])
    @log.level = config['log.debug'] ? Logger::DEBUG : Logger::INFO
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

  def error error
    @mutex.synchronize do
      @log.error "error! #{error.message}"
      error.backtrace.each { |error| @log.error error }
    end if @log.error?
  end

  def debug?
    @log.debug?
  end

  def TraceLog.hex bytes
    (bytes.collect {|byte| "%02x " % (byte & 0xFF)}).join
  end

end
