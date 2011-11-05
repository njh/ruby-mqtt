#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'mqtt/client'

client = MQTT::Client.new('localhost')
client.connect do |c|

  c.publish('test', "The time is: #{Time.now}")

end
