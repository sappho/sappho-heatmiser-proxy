require 'heatmiser_crc'
require 'thread'
require 'timeout'

class Heatmiser

  @lastStatus = nil
  @commandQueue = []
  @queueMutex = Mutex.new
  @statusMutex = Mutex.new

  def initialize hostname, pin
    @socket = TCPSocket.open(hostname, 8068)
    @pin = pin
    @timestamp = Time.now - 99
    Thread.new do
      queryCommand = addCRCToCommand [0x93, 0x0B, 0x00, @pin & 0xFF, @pin >> 8, 0x00, 0x00, 0xFF, 0xFF]
      loop do
        if (Time.now - @timestamp) >= 4
          command = queryCommand
          @queueMutex.synchronize do
            command = @commandQueue.shift if @commandQueue.size > 0
          end
          @socket.write command
          status = nil
          begin
            timeout 1 do
              status = socket.read 81
            end
            crcHi = status.pop
            crcLo = status.pop
            crc = HeatmiserCRC.new status
            if crc.crcHi != crcHi or crc.crcLo != crcLo
              status = nil
            else
              status << crcLo
              status << crcHi
            end
          rescue
            status = nil
          end
          @statusMutex.synchronize do
            @lastStatus = status
          end if status
          puts @lastStatus
          @timestamp = Time.now
        end
        sleep 0.1
      end
    end.run
  end

  def addCRCToCommand command
    crc = HeatmiserCRC.new command
    command << crc.crcLo
    command << crc.crcHi
    command
  end

end

Heatmiser.new ARGV[0], Integer(ARGV[1])
loop do
  sleep 0.1
end
