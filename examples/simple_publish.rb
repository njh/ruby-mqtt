#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'mqtt'

client = MQTT::Client.new('mqtt.example.com')
client.connect('simple_publish_example') do |c|

  c.publish('test', "The time is: #{Time.now}")

end
