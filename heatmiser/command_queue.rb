require 'singleton'
require 'thread'
require 'trace_log'

class CommandQueue

  include Singleton

  @queue = []
  @mutex = Mutex.new
  @log = TraceLog.instance

  def push clientIP, command
    @log.info "client #{clientIP} requests command:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}"
    @mutex.synchronize do
      @queue << {
          :clientIP => clientIP,
          :command => command.dup
      }
    end
  end

  def get
    command = nil
    @mutex.synchronize do
      if @queue.size > 0
        queue = @queue[0]
        command = queue[:command].dup
        @log.info "client #{queue[:clientIP]} command executing:#{(command.collect {|byte| " %02x" % (byte & 0xFF)}).join}"
      end
    end
    command
  end

  def completed
    @mutex.synchronize do
      if @queue.size > 0
        queue = @queue[0]
        @log.info "client #{queue[:clientIP]} command completed:#{(queue[:command].collect {|byte| " %02x" % (byte & 0xFF)}).join}"
        @queue.shift
      end
    end
  end

end
