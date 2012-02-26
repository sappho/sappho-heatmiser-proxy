# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'sappho-heatmiser-proxy/heatmiser'
      require 'sappho-heatmiser-proxy/heatmiser_proxy'
      require 'thread'

      class CommandLine

        def CommandLine.process
          Thread.abort_on_exception = true
          hm = Heatmiser.new
          hm.monitor
          HeatmiserProxy.new.serve
          hm.wait
        end

      end

    end
  end
end
