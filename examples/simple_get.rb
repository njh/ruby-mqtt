#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'mqtt'


client = MQTT::Client.new('mqtt.example.com')
client.connect('simple_get')

client.subscribe('$SYS/#')

loop do
  topic,message = client.get
  puts "#{topic}: #{message}"
end

client.disconnect
