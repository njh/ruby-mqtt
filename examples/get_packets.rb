#!/usr/bin/env ruby
#
# Connect to a MQTT server, subscribe to all topics
# and then loop, displaying the packets received.
#

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'mqtt'

MQTT::Client.connect('test.mosquitto.org') do |client|
  # If you pass a block to the get_packet method, then it will loop
  client.get_packet('#') do |packet|
    p packet
  end
end
