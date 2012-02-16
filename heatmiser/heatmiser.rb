require 'heatmiser_crc'
require 'thread'

class Heatmiser

  @lastStatus = nil
  @commandQueue = []
  @mutex = Mutex.new

  def initialize hostname, pin
    #@socket = TCPSocket.open(hostname, 8068)
    @pin = pin
    @timestamp = Time.now
    Thread.new {
      loop do
        sleep 0.1
        puts Time.now - @timestamp
      end
    }.run
  end

  def addCRCToCommand command
    crc = HeatmiserCRC.new command
    command << crc.crcLo
    command << crc.crcHi
    command
  end

end

Heatmiser.new '', 1234
loop do
  sleep 0.1
end
