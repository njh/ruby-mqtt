#!/usr/bin/env ruby
#
# Send a MQTT-SN Publish packet at QoS -1
# over UDP to a MQTT-SN server
#

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'socket'
require 'mqtt'


socket = UDPSocket.new
socket.connect('localhost', MQTT::SN::DEFAULT_PORT)
socket << MQTT::SN::Packet::Publish.new(
  :topic_id => 'TT',
  :topic_id_type => :short,
  :data => "The time is: #{Time.now}",
  :qos => -1
)
socket.close
