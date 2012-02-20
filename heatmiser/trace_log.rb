require 'singleton'
require 'thread'
require 'logger'
require 'yaml'

class TraceLog

  include Singleton

  @mutex = Mutex.new

  def initialize
    config = YAML.load_file 'log.yml'
    @log = Logger.new(config['stdout'] ? STDOUT : config['filename'])
    @log.level = config['debug'] ? Logger::DEBUG : Logger::INFO
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
