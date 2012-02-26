# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'singleton'
      require 'thread'
      require 'sappho-heatmiser-proxy/trace_log'

      class CommandQueue

        include Singleton

        def initialize
          @queue = []
          @mutex = Mutex.new
          @log = TraceLog.instance
        end

        def push clientIP, command
          @log.info "client #{clientIP} requests command: #{TraceLog.hex command}"
          @mutex.synchronize do
            @queue << {
                :clientIP => clientIP,
                :command => command.dup
            }
          end
        end

        def get
          command = nil
          @mutex.synchronize do
            if @queue.size > 0
              queue = @queue[0]
              command = queue[:command].dup
              @log.info "client #{queue[:clientIP]} command executing: #{TraceLog.hex command}"
            end
          end
          command
        end

        def completed
          @mutex.synchronize do
            if @queue.size > 0
              queue = @queue[0]
              @log.info "client #{queue[:clientIP]} command completed: #{TraceLog.hex queue[:command]}"
              @queue.shift
            end
          end
        end

      end

    end
  end
end
