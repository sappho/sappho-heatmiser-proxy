require 'singleton'
require 'thread'
require 'trace_log'
require 'system_configuration'

class ClientRegister

  include Singleton

  def initialize
    @mutex = Mutex.new
    @clients = {}
    @max = Integer SystemConfiguration.instance.config['heatmiser.clients.max']
    @log = TraceLog.instance
  end

  def register client
    @mutex.synchronize do
      ip = client.getpeername
      @clients[client] = ip = (4 ... 8).map{|pos|ip[pos]}.join('.')
      @log.info "client #{ip} connected"
      log
    end
  end

  def unregister client
    @mutex.synchronize do
      ip = @clients[client]
      @clients.delete client
      @log.info "client #{ip} disconnected"
      log
    end
  end

  def ip client
    @mutex.synchronize { @clients[client] }
  end

  def maxAlreadyConnected?
    @mutex.synchronize { @clients.size >= @max }
  end

  private

  def log
    @log.info "clients: #{(@clients.collect{|client, ip| ip}).join ' '}"
  end

end
