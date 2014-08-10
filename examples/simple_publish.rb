#!/usr/bin/env ruby
#
# Connect to a MQTT server, send message and disconnect again.
#

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'mqtt'

MQTT::Client.connect('test.mosquitto.org') do |client|

  client.publish('test', "The time is: #{Time.now}")

end
