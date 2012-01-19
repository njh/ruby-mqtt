#!/usr/bin/env ruby
#
# Connect to a local MQTT broker, subscribe to all topics
# and then loop, displaying any messages received.
#

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'mqtt'

MQTT::Client.connect('rotter.national.core.bbc.co.uk') do |client|
  client.get('#') do |topic,message|
    puts "#{topic}: #{message}"
  end
end
