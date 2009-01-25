#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'mqtt'


client = MQTT::Client.new('mqtt.example.com')
client.connect('simple_get')

client.subscribe('$SYS/#')

loop do
  client.get do |topic,message|
    puts "#{topic}: #{message}"
  end
end

client.disconnect
