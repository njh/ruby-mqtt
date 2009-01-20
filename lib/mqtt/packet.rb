#!/usr/bin/env ruby

module MQTT

  # Class representing a MQTT Packet
  class Packet #:nodoc: all
    attr_accessor :type       # The packet type
    attr_accessor :dup        # Duplicate delivery flag
    attr_accessor :qos        # Quality of Service level
    attr_accessor :retain     # Retain flag
    attr_accessor :payload    # Packets Payload (everything after fixed header)

    def initialize(type)
      @type = type
      @dup = 0
      @qos = 0
      @retain = 0
      @payload = ''
    end

    # Add an array of bytes to the packet
    def add_bytes(*bytes)
      @payload += bytes.pack('c*')
    end

    # Add a string to the packet
    # (preceded by the length of the string)
    def add_string(str)
      @payload += [str.size].pack('n') + str
    end

    # Add some data to the payload
    def add_data(data)
      @payload += data
    end
    
    # Serialise the packet
    def to_s
      # FIXME: add dup,qos and retain
      header = [(@type<<4),(@payload.length&0x7F)] 
      header.pack('c*') + @payload
    end
    
  end
  
end
