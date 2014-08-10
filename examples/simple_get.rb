#!/usr/bin/env ruby
#
# Connect to a MQTT server, subscribe to all topics
# and then loop, displaying any messages received.
#

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'mqtt'

MQTT::Client.connect('test.mosquitto.org') do |client|
  # If you pass a block to the get method, then it will loop
  client.get('#') do |topic,message|
    puts "#{topic}: #{message}"
  end
end
