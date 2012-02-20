require 'singleton'
require 'thread'

class CommandQueue

  include Singleton

  @queue = []
  @mutex = Mutex.new

  def push clientIP, command

  end

  def get

  end

  def pop

  end

end