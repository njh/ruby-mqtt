#!/usr/bin/env ruby

require 'mqtt'

module MQTT

  # Class representing a MQTT Packet
  # Performs binary encoding and decoding of headers
  class Packet #:nodoc: all
    attr_reader :type      # The packet type
    attr_reader :dup       # Duplicate delivery flag
    attr_reader :retain    # Retain flag
    attr_reader :qos       # Quality of Service level
    attr_reader :body      # Packet's body (everything after fixed header)
  
    # Read in a packet from a socket
    def self.read(sock)
      header = sock.read(2)
      raise MQTT::ProtocolException if header.nil?
      byte1,byte2 = header.unpack('C*')

      # FIXME: support decoding of multi-byte length header

      packet = MQTT::Packet.new(
        :type => ((byte1 & 0xF0) >> 4),
        :dup => ((byte1 & 0x08) >> 3),
        :qos => ((byte1 & 0x06) >> 1),
        :retain => ((byte1 & 0x01) >> 0)
      )
      packet.body = sock.read(byte2)

      return packet
    end

    # Create a new empty packet
    def initialize(args={})
      self.type = args[:type] || :invalid
      self.dup = args[:dup] || false
      self.qos = args[:qos] || 0
      self.retain = args[:retain] || false
      self.body = args[:body] || ''
    end
    
    def type=(arg)
      if arg.kind_of?(Integer)
        # Convert type identifier to symbol
        @type = MQTT::PACKET_TYPES[arg]
      else
        @type = arg.to_sym
        # FIXME: raise exception if packet type is invalid?
      end
    end

    # Return the identifer for this packet type
    def type_id
      raise "No packet type set for this packet" if @type.nil?
      index = MQTT::PACKET_TYPES.index(@type)
      raise "Invalid packet type: #{@type}" if index.nil?
      return index
    end
    
    def dup=(arg)
      if arg.kind_of?(Integer)
        @dup = (arg != 0 ? true : false)
      else
        @dup = arg
      end
    end
    
    def retain=(arg)
      if arg.kind_of?(Integer)
        @retain = (arg != 0 ? true : false)
      else
        @retain = arg
      end
    end
    
    def qos=(arg)
      @qos = arg.to_i
    end
    
    def body=(arg)
      @body = arg.to_s
    end




    
    # Add an array of bytes to the end of the packet's body
    def add_bytes(*bytes)
      @body += bytes.pack('C*')
    end

    # Add a 16-bit unsigned integer to the end of the packet's body
    def add_short(val)
      @body += [val.to_i].pack('n')
    end
    
    # Add some raw data to the end of the packet's body
    def add_data(data)
      data = data.to_s unless data.is_a?(String)
      @body += data
    end

    # Add a string to the end of the packet's body
    # (preceded by the length of the string)
    def add_string(str)
      str = str.to_s unless str.is_a?(String)
      add_short(str.size)
      add_data(str)
    end


    # Remove a 16-bit unsigned integer from the front on the body
    def shift_short
      bytes = @body.slice!(0..1)
      bytes.unpack('n').first
    end
    
    # Remove n bytes from the front on the body
    def shift_bytes(bytes)
      @body.slice!(0...bytes).unpack('C*')
    end
    
    # Remove n bytes from the front on the body
    def shift_data(bytes)
      @body.slice!(0...bytes)
    end
    
    # Remove string from the front on the body
    def shift_string
      len = shift_short
      shift_data(len)
    end

    
    # Serialise the packet
    def to_s
      # Encode the 2-byte fixed header
      header = [
        ((type_id.to_i & 0x0F) << 4) |
        ((dup ? 0x1 : 0x0) << 3) |
        ((qos.to_i & 0x03) << 1) |
        (retain ? 0x1 : 0x0),
        (@body.length & 0x7F)
      ]
      # FIXME: support multi-byte length header
      header.pack('C*') + @body
    end
    
    def inspect
      format("#<MQTT::Packet:0x%1x ", object_id)+
      "type=#{@type}, dup=#{@dup}, retain=#{@retain}, "+
      "qos=#{@qos}, body.size=#{@body.size}>"
    end
    
  end
  
end
