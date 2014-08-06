#!/usr/bin/env ruby
#
# Authenticate to a server, subscribe to a topic and publish

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'mqtt'


MQTT::Client.connect(
  :host => 'test.mosquitto.org',
  :username => 'test',
  :password => 'password'
) do |client|
  puts 'connected'

  # We have to do this in a separate thread or process (or a different computer)
  Thread.new do
    20.times do # We could do it forever, but 20 times is good enough
      sleep(0.5)  # slow it down because computers are too fast
      client.publish('test/ruby/authentication', "The time is now #{Time.now}")
    end
  end

  # when a block is passed to #get, it loops infinitely so this has to be the last line of our program
  client.get("test/ruby/#") do |topic, msg|
    puts "Got message '#{msg}' on topic '#{topic}'"
  end

end
