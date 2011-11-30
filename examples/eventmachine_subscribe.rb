#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'mqtt'


class MyConnection < MQTT::ClientConnection

  def receive_msg(packet)
    p packet
  end

end


EventMachine.run do
  MyConnection.connect('localhost') do |c|
    c.subscribe('test')
  end
end
