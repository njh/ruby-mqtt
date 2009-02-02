#!/usr/bin/env ruby

require 'mqtt'

module MQTT

  # Class representing a MQTT Packet
  # Performs binary encoding and decoding of headers
  class Packet
    attr_reader :type      # The packet type
    attr_reader :dup       # Duplicate delivery flag
    attr_reader :retain    # Retain flag
    attr_reader :qos       # Quality of Service level
    attr_reader :body      # Packet's body (everything after fixed header)
  
    # Read in a packet from a socket
    def self.read(socket)

      # Create a packet object
      header = read_byte(socket)
      packet = MQTT::Packet.new(
        :type => ((header & 0xF0) >> 4),
        :dup => ((header & 0x08) >> 3),
        :qos => ((header & 0x06) >> 1),
        :retain => ((header & 0x01) >> 0)
      )
      
      # Read in the packet length
      multiplier = 1 
      body_len = 0 
      begin
        digit = read_byte(socket)
        body_len += ((digit & 0x7F) * multiplier)
        multiplier *= 0x80
      end while ((digit & 0x80) != 0x00)
      # FIXME: only allow 4 bytes?

      # Read in the packet body
      packet.body = socket.read(body_len)

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
    
    # Set the packet type
    # Can either by the packet type id (integer)
    # Or the packet type as a symbol/string
    # See the MQTT module for an enumeration of packet types.
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
    
    # Set the dup flag (true/false)
    def dup=(arg)
      if arg.kind_of?(Integer)
        @dup = (arg != 0 ? true : false)
      else
        @dup = arg
      end
    end
    
    # Set the retain flag (true/false)
    def retain=(arg)
      if arg.kind_of?(Integer)
        @retain = (arg != 0 ? true : false)
      else
        @retain = arg
      end
    end
    
    # Set the Quality of Service level (0/1/2)
    def qos=(arg)
      @qos = arg.to_i
    end
    
    # Set (replace) the packet body
    def body=(arg)
      # FIXME: only allow 268435455 bytes?
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
      # Encode the fixed header
      header = [
        ((type_id.to_i & 0x0F) << 4) |
        ((dup ? 0x1 : 0x0) << 3) |
        ((qos.to_i & 0x03) << 1) |
        (retain ? 0x1 : 0x0)
      ]
      
      # Build up the body length field bytes
      body_size = @body.size
      begin
        digit = (body_size % 128)
        body_size = (body_size / 128)
        # if there are more digits to encode, set the top bit of this digit
        digit |= 0x80 if (body_size > 0)
        header.push(digit)
      end while (body_size > 0)

      # Convert header to binary and add on body
      header.pack('C*') + @body
    end
    
    def inspect
      format("#<MQTT::Packet:0x%01x ", object_id)+
      "type=#{@type}, dup=#{@dup}, retain=#{@retain}, "+
      "qos=#{@qos}, body.size=#{@body.size}>"
    end
    
    private
    
    # Read and unpack a single byte from socket
    def self.read_byte(socket)
      byte = socket.read(1)
      raise MQTT::ProtocolException if byte.nil?
      byte.unpack('C').first
    end
    
  end
  
end
