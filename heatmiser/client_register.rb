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
    @mutex.synchronize do
      raise "duplicate client connection on #{@clients[client]}" if @clients.has_key? client
      ip = client.getpeername
      ip = (4 ... 8).map{|pos|ip[pos]}.join('.')
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
      begin
        client.close
      rescue
      end
      TraceLog.instance.info "client #{ip} disconnected"
      log
    end
  end

  private

  def log
    TraceLog.instance.info "clients: #{(@clients.collect {|client, ip| ip}).join ' '}"
  end

end
