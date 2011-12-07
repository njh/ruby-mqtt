#!/usr/bin/env ruby

require 'eventmachine'
require 'logger'
require 'socket'
require 'thread'
require 'timeout'

require "mqtt/version"

module MQTT

  DEFAULT_PORT = 1883

  class Exception < Exception
  end

  class ProtocolException < MQTT::Exception
  end
  
  class NotConnectedException < MQTT::Exception
  end

  autoload :Client,           'mqtt/client'
  autoload :ClientConnection, 'mqtt/client_connection'
  autoload :Connection,       'mqtt/connection'
  autoload :Packet,           'mqtt/packet'
  autoload :Proxy,            'mqtt/proxy'
  autoload :Server,           'mqtt/server'
  autoload :ServerConnection, 'mqtt/server_connection'

end
