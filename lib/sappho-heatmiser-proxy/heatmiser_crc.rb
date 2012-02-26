# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      class HeatmiserCRC

        LookupHi = [
            0x00, 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70,
            0x81, 0x91, 0xA1, 0xB1, 0xC1, 0xD1, 0xE1, 0xF1
        ]
        LookupLo = [
            0x00, 0x21, 0x42, 0x63, 0x84, 0xA5, 0xC6, 0xE7,
            0x08, 0x29, 0x4A, 0x6B, 0x8C, 0xAD, 0xCE, 0xEF
        ]
        attr_reader :crcHi, :crcLo

        def initialize bytes
          @bytes = bytes
          @crcHi = 0xFF
          @crcLo = 0xFF
          bytes.each do |byte|
            addNibble byte >> 4
            addNibble byte & 0x0F
          end
        end

        def appendCRC
          @bytes << @crcLo << @crcHi
        end

        private

        def addNibble nibble
          t = ((@crcHi >> 4) ^ nibble) & 0x0F
          @crcHi = (((@crcHi << 4) & 0xFF) | (@crcLo >> 4)) ^ LookupHi[t]
          @crcLo = ((@crcLo << 4) & 0xFF) ^ LookupLo[t]
        end

      end

    end
  end
end
