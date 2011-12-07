#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'mqtt'

EventMachine.run do
  # hit Control + C to stop
  Signal.trap("INT")  { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }

  EventMachine.start_server("0.0.0.0", 1883, MQTT::ServerConnection)
end
