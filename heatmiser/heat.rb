
require 'socket'
require 'timeout'
require 'heatmiser_crc'

def makeReadCommand pin, function = 0x93
  command = [function, 0x0B, 0x00, pin & 0xFF, pin >> 8, 0x00, 0x00, 0xFF, 0xFF]
  crc = HeatmiserCRC.new command
  command << crc.crcLo
  command << crc.crcHi
  puts command
  command.pack 'c*'
end

def doComms pin
  cmd = makeReadCommand pin
  socket = TCPSocket.open('192.168.2.61', 8068)
  socket.write cmd
  reply = socket.read 81
  puts reply.unpack('c*')
end

makeReadCommand 4792
