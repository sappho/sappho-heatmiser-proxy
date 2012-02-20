require 'heatmiser'
require 'heatmiser_proxy'
require 'thread'

Thread.abort_on_exception = true

hm = Heatmiser.instance
hm.hostname = ARGV[0]
hm.pin = Integer ARGV[1]
hm.monitor
HeatmiserProxy.new.serve
hm.wait
