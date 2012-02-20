require 'singleton'
require 'thread'
require 'trace_log'

class CommandQueue

  include Singleton

  @queue = []
  @mutex = Mutex.new
  @log = TraceLog.instance

  def push clientIP, command
    @log.info "client #{clientIP} requests command: #{TraceLog.hex command}"
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
        @log.info "client #{queue[:clientIP]} command executing: #{TraceLog.hex command}"
      end
    end
    command
  end

  def completed
    @mutex.synchronize do
      if @queue.size > 0
        queue = @queue[0]
        @log.info "client #{queue[:clientIP]} command completed: #{TraceLog.hex queue[:command]}"
        @queue.shift
      end
    end
  end

end
