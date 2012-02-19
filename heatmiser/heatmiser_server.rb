require 'heatmiser'
require 'heatmiser_proxy'
require 'thread'

Thread.abort_on_exception = true

hm = Heatmiser.new(ARGV[0], Integer(ARGV[1]))
hm.monitor
hmp = HeatmiserProxy.new hm
hmp.monitor
hm.wait
