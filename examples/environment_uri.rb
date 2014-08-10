#!/usr/bin/env ruby
#
# Connect to a MQTT server based on a URI in
# an environment variable
#

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'mqtt'

# This environment variable may be set by the shell
#
# Note that you need Ruby 2.0+ to use TLS with test.mosquitto.org
#
ENV['MQTT_SERVER'] = 'mqtts://test.mosquitto.org:8883'

MQTT::Client.connect do |client|
  puts "Connected"

  # If you pass a block to the get method, then it will loop
  client.get('bbc/livetext/#') do |topic,message|
    puts "#{topic}: #{message}"
  end
end
