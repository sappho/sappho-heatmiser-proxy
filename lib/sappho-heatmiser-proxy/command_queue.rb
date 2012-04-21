# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'singleton'
      require 'thread'
      require 'sappho-basics/auto_flush_log'

      class CommandQueue

        include Singleton, Sappho::LogUtilities

        def initialize
          @refreshStatus = false
          @queue = []
          @mutex = Mutex.new
          @log = Sappho::ApplicationAutoFlushLog.instance
        end

        def refreshStatus clientIP
          @log.info "client #{clientIP} requests status refresh"
          @mutex.synchronize do
            @refreshStatus = true
          end
        end

        def refreshStatus
          @mutex.synchronize do
            required = @refreshStatus
            @refreshStatus = false
            required
          end
        end

        def push clientIP, command
          @log.info "client #{clientIP} requests command: #{hexString command}"
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
              @log.info "client #{queue[:clientIP]} command executing: #{hexString command}"
            end
          end
          command
        end

        def completed
          @mutex.synchronize do
            if @queue.size > 0
              queue = @queue[0]
              @log.info "client #{queue[:clientIP]} command completed: #{hexString queue[:command]}"
              @queue.shift
            end
          end
        end

      end

    end
  end
end
