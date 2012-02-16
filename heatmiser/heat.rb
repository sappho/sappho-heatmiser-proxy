
require 'socket'
require 'timeout'

class CRC

  LookupHi = [
      0x00, 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70,
      0x81, 0x91, 0xA1, 0xB1, 0xC1, 0xD1, 0xE1, 0xF1
  ]
  LookupLo = [
      0x00, 0x21, 0x42, 0x63, 0x84, 0xA5, 0xC6, 0xE7,
      0x08, 0x29, 0x4A, 0x6B, 0x8C, 0xAD, 0xCE, 0xEF
  ]
  attr_reader :crcHi, :crcLo

  def initialize bytes = []
    @crcHi = 0xFF
    @crcLo = 0xFF
    addBytes bytes
  end

  def addBytes bytes
    bytes.each do |byte|
      addNibble byte >> 4
      addNibble byte & 0x0F
    end
  end

  private

  def addNibble nibble
    t = ((@crcHi >> 4) ^ nibble) & 0x0F
    @crcHi = (((@crcHi << 4) & 0xFF) | (@crcLo >> 4)) ^ LookupHi[t]
    @crcLo = ((@crcLo << 4) & 0xFF) ^ LookupLo[t]
  end

end

def makeReadCommand pin, function = 0x93
  command = [function, 0x0B, 0x00, pin & 0xFF, pin >> 8, 0x00, 0x00, 0xFF, 0xFF]
  crc = CRC.new command
  command << crc.crcLo
  command << crc.crcHi
  command.pack 'c*'
end

def doComms pin
  cmd = makeReadCommand pin
  socket = TCPSocket.open('192.168.2.61', 8068)
  socket.write cmd
  reply = socket.read 81
  puts reply.unpack('c*')
end

doComms 4792
