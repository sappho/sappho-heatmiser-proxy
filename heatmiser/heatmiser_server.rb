require 'heatmiser'

hm = Heatmiser.new(ARGV[0], Integer(ARGV[1]))
hm.monitor
loop do
  sleep 2.5
  status = hm.lastStatus
  puts "#{(status[:raw].collect {|byte| "%02x " % (byte & 0xFF)}).join}#{status[:requestedTemperature]} #{status[:sensedTemperature]} #{status[:heatOn]} #{status[:keyLockOn]} #{status[:frostProtectOn]} #{status[:timeSinceLastValid]} #{status[:dayOfWeek]} #{status[:deviceTimeOffset]}" if status[:valid]
end
