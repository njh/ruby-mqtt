#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'mqtt'

proxy = MQTT::Proxy.new(
    :local_host => '0.0.0.0',
    :local_port => 1883,
    :broker_host => 'test.mosquitto.org',
    :broker_port => 1883
)

proxy.client_filter = lambda { |packet|
  puts "From client: #{packet.inspect}"
  return packet
}

proxy.broker_filter = lambda { |packet|
  puts "From broker: #{packet.inspect}"
  return packet
}

# Start the proxy
proxy.run
