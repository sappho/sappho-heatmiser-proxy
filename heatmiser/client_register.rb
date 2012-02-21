require 'singleton'
require 'thread'
require 'trace_log'

class ClientRegister

  include Singleton

  def initialize
    @mutex = Mutex.new
    @clients = {}
  end

  def put client, max = 8
    ip = client.getpeername
    ip = (4 ... 8).map{|pos|ip[pos]}.join('.')
    @mutex.synchronize do
      @clients[client] = ip
      TraceLog.instance.info "client #{ip} connected"
      log
      raise "limit of #{max} heatmiser clients has been exceeded" if @clients.size > max
    end
  end

  def ip client
    @mutex.synchronize { @clients[client] }
  end

  def close client
    @mutex.synchronize do
      ip = @clients[client]
      @clients.delete client
      client.close
      TraceLog.instance.info "client #{ip} disconnected"
      log
    end
  end

  private

  def log
    TraceLog.instance.info "clients: #{(@clients.collect {|client, ip| ip}).join ' '}"
  end

end
