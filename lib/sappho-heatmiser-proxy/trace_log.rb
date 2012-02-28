# See https://github.com/sappho/sappho-heatmiser-proxy/wiki for project documentation.
# This software is licensed under the GNU Affero General Public License, version 3.
# See http://www.gnu.org/licenses/agpl.html for full details of the license terms.
# Copyright 2012 Andrew Heald.

module Sappho
  module Heatmiser
    module Proxy

      require 'singleton'
      require 'thread'
      require 'logger'
      require 'sappho-heatmiser-proxy/system_configuration'
      require 'sappho-heatmiser-proxy/version'

      class TraceLog

        include Singleton

        def initialize
          @mutex = Mutex.new
          $stdout.sync = true
          @log = Logger.new $stdout
          @log.level = SystemConfiguration.instance.config['log.debug'] ? Logger::DEBUG : Logger::INFO
          @log.info "#{NAME} version #{VERSION} - #{HOMEPAGE}"
        end

        def info message
          @mutex.synchronize do
            @log.info message
          end if @log.info?
        end

        def debug message
          @mutex.synchronize do
            @log.debug message
          end if @log.debug?
        end

        def error error
          @mutex.synchronize do
            @log.error "error! #{error.message}"
            error.backtrace.each { |error| @log.error error }
          end if @log.error?
        end

        def debug?
          @log.debug?
        end

        def TraceLog.hex bytes
          (bytes.collect {|byte| "%02x " % (byte & 0xFF)}).join
        end

      end

    end
  end
end
