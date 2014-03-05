#!/usr/bin/env ruby

require 'logger'
require 'socket'
require 'thread'
require 'timeout'

require 'mqtt/version'

# String encoding monkey patch for Ruby 1.8
unless String.method_defined?(:force_encoding)
  require 'mqtt/patches/string_encoding.rb'
end

module MQTT

  DEFAULT_PORT = 1883

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
