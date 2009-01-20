#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'mqtt'


client = MQTT::Client.new('hadrian.aelius.com')
client.connect('myclient')

sleep 2

client.publish('test',Time.now.to_s)

sleep 2

client.disconnect
