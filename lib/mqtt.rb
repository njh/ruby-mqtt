#!/usr/bin/env ruby

require 'logger'
require 'socket'
require 'thread'
require 'timeout'
require "mqtt/version"


module MQTT

  NETWORK_MODE = (ENV['RUBY_MQTT_NETWORK_MODE'] ? ENV['RUBY_MQTT_NETWORK_MODE'] : 'vanilla')

  DEFAULT_HOST = 'localhost'
  DEFAULT_PORT = 1883

  class Exception < Exception
  end

  class ProtocolException < MQTT::Exception
  end

  class NotConnectedException < MQTT::Exception
  end

  autoload :Packet,   'mqtt/packet'

  case NETWORK_MODE
  when 'eventmachine'
    require 'eventmachine'
    autoload :Proxy,    'mqtt/em-proxy'
    autoload :Client,   'mqtt/em-client'
  else
    autoload :Proxy,    'mqtt/proxy'
    autoload :Client,   'mqtt/client'
  end
end

