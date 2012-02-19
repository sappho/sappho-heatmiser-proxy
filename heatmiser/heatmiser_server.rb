require 'heatmiser'
require 'thread'

Thread.abort_on_exception = true

hm = Heatmiser.new(ARGV[0], Integer(ARGV[1]))
hm.monitor
hm.wait
