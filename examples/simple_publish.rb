#!/usr/bin/env ruby
#
# Connect to local MQTT Broker, send message and disconnect again.
#

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'mqtt'

MQTT::Client.connect('localhost') do |client|

  client.publish('test', "The time is: #{Time.now}")

end
