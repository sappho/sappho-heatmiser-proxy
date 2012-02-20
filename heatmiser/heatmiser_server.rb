require 'heatmiser'
require 'heatmiser_proxy'
require 'thread'

Thread.abort_on_exception = true

hm = Heatmiser.instance
hm.monitor
HeatmiserProxy.new.serve
hm.wait
