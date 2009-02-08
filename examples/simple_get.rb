#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'mqtt/client'

client = MQTT::Client.new('mqtt.example.com')
client.connect do
  client.subscribe('#')
  loop do
    topic,message = client.get
    puts "#{topic}: #{message}"
  end
end
