#!/usr/bin/env ruby
#
# Connect to a local MQTT broker, subscribe to all topics
# and then loop, displaying any messages received.
#

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'mqtt'

MQTT::Client.connect('localhost') do |client|
  client.subscribe('#')
  loop do
    topic,message = client.get
    puts "#{topic}: #{message}"
  end
end
