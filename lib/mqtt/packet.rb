#!/usr/bin/env ruby

module MQTT

  # Class representing a MQTT Packet
  # Performs binary encoding and decoding of headers
  class Packet #:nodoc: all
    attr_accessor :type       # The packet type
    attr_accessor :dup        # Duplicate delivery flag
    attr_accessor :qos        # Quality of Service level
    attr_accessor :retain     # Retain flag
    attr_accessor :payload    # Packet's Payload (everything after fixed header)
  
    # Read in a packet from a socket
    def self.read(sock)
      header = sock.readpartial(2)
      raise MQTT::ProtocolException if header.nil?
      byte1,byte2 = header.unpack('C*')

      # FIXME: support decoding of multi-byte length header

      packet = MQTT::Packet.new(
        :type => ((byte1 & 0xF0) >> 4),
        :dup => ((byte1 & 0x08) >> 3),
        :qos => ((byte1 & 0x06) >> 1),
        :retain => ((byte1 & 0x01) >> 0)
      )
      packet.payload = sock.readpartial(byte2)

      return packet
    end

    # Create a new empty packet
    def initialize(args={})
      self.type = args[:type] || nil
      self.dup = args[:dup] || false
      self.qos = args[:qos] || 0
      self.retain = args[:retain] || false
      self.payload = args[:payload] || ''
    end
    
    def type=(arg)
      if arg.kind_of?(Integer)
        # Convert type identifier to symbol
        @type = MQTT::PACKET_TYPES[arg]
      else
        @type = arg
      end
    end
    
    def dup=(arg)
      @dup = (arg == 1 ? true : false)
    end
    
    def retain=(arg)
      @retain = (arg == 1 ? true : false)
    end

    # Return the identifer for this packet type
    def type_id
      raise "No packet type set for this packet" if @type.nil?
      index = MQTT::PACKET_TYPES.index(@type)
      raise "Invalid packet type: #{@type}" if index.nil?
      return index
    end




    
    # Add an array of bytes to the end of the packet's payload
    def add_bytes(*bytes)
      @payload += bytes.pack('C*')
    end

    # Add a 16-bit unsigned integer to the end of the packet's payload
    def add_short(val)
      @payload += [val.to_i].pack('n')
    end
    
    # Add some raw data to the end of the packet's payload
    def add_data(data)
      @payload += data
    end

    # Add a string to the end of the packet's payload
    # (preceded by the length of the string)
    def add_string(str)
      str = str.to_s unless str.is_a?(String)
      add_short(str.size)
      add_data(str)
    end


    # Remove a 16-bit unsigned integer from the front on the payload
    def shift_short
      bytes = @payload.slice!(0..1)
      bytes.unpack('n').first
    end
    
    # Remove n bytes from the front on the payload
    def shift_bytes(bytes)
      @payload.slice!(0...bytes).unpack('C*')
    end
    
    # Remove n bytes from the front on the payload
    def shift_data(bytes)
      @payload.slice!(0...bytes)
    end
    
    # Remove string from the front on the payload
    def shift_string
      len = shift_short
      shift_data(len)
    end

    
    # Serialise the packet
    def to_s
      # Encode the 2-byte fixed header
      header = [
        ((type_id.to_i << 4) & 0xF0) +
        (((dup ? 1 : 0) << 3) & 0x08) +
        ((qos.to_i << 2) & 0x06) +
        (((retain ? 1 : 0) << 0) & 0x01),
        (@payload.length & 0x7F)
      ]
      # FIXME: support multi-byte length header
      header.pack('C*') + @payload
    end
    
    def inspect
      "#<MQTT::Packet:#{object_id} type=#{type.to_s}, dup=#{@dup}, "+
      "retain=#{@retain}, qos=#{@qos}, payload.size=#{@payload.size}>"
    end
    
  end
  
end
