#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'mqtt'

client = MQTT::Client.new('localhost')
client.connect do
  client.subscribe('#')
  loop do
    topic,message = client.get
    puts "#{topic}: #{message}"
  end
end
