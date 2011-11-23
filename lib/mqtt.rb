#!/usr/bin/env ruby

require 'logger'
require 'socket'
require 'thread'
require 'timeout'

require "mqtt/version"

module MQTT

  class Exception < Exception
  end

  class ProtocolException < MQTT::Exception
  end
  
  class NotConnectedException < MQTT::Exception
  end

  autoload :Client,   'mqtt/client'
  autoload :Packet,   'mqtt/packet'
  autoload :Proxy,    'mqtt/proxy'

end
