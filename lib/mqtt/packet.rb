# encoding: BINARY

module MQTT
  # Class representing a MQTT Packet
  # Performs binary encoding and decoding of headers
  class Packet
    # The version number of the MQTT protocol to use (default 3.1.0)
    attr_accessor :version

    # Identifier to link related control packets together
    attr_accessor :id

    # Array of 4 bits in the fixed header
    attr_accessor :flags

    # The length of the parsed packet body
    attr_reader :body_length

    # Default attribute values
    ATTR_DEFAULTS = {
      :version => '3.1.0',
      :id => 0,
      :body_length => nil
    }

    # Read a packet from a socket
    # @param socket [IO] Socket to read from
    # @param version [String] Optional MQTT version ('3.1.0', '3.1.1', '5.0') for context
    def self.read(socket, version: nil)
      # Read in the packet header and create a new packet object
      packet = create_from_header(
        read_byte(socket)
      )
      packet.validate_flags

      # Read in the packet length
      multiplier = 1
      body_length = 0
      pos = 1

      loop do
        digit = read_byte(socket)
        body_length += ((digit & 0x7F) * multiplier)
        multiplier *= 0x80
        pos += 1
        break if (digit & 0x80).zero? || pos > 4
      end

      # Store the expected body length in the packet
      packet.instance_variable_set('@body_length', body_length)

      # Set version before parsing body so properties are handled correctly
      packet.version = version if version

      # Read in the packet body
      packet.parse_body(socket.read(body_length))

      packet
    end

    # Parse buffer into new packet object
    # @param buffer [String] Raw packet data
    # @param version [String] Optional MQTT version ('3.1.0', '3.1.1', '5.0') for context
    def self.parse(buffer, version: nil)
      packet = parse_header(buffer)
      packet.version = version if version
      packet.parse_body(buffer)
      packet
    end

    # Parse the header and create a new packet object of the correct type
    # The header is removed from the buffer passed into this function
    def self.parse_header(buffer)
      # Check that the packet is a long as the minimum packet size
      if buffer.bytesize < 2
        raise ProtocolException, 'Invalid packet: less than 2 bytes long'
      end

      # Create a new packet object
      bytes = buffer.unpack('C5')
      packet = create_from_header(bytes.first)
      packet.validate_flags

      # Parse the packet length
      body_length = 0
      multiplier = 1
      pos = 1

      loop do
        if buffer.bytesize <= pos
          raise ProtocolException, 'The packet length header is incomplete'
        end

        digit = bytes[pos]
        body_length += ((digit & 0x7F) * multiplier)
        multiplier *= 0x80
        pos += 1
        break if (digit & 0x80).zero? || pos > 4
      end

      # Store the expected body length in the packet
      packet.instance_variable_set('@body_length', body_length)

      # Delete the fixed header from the raw packet passed in
      buffer.slice!(0...pos)

      packet
    end

    # Create a new packet object from the first byte of a MQTT packet
    def self.create_from_header(byte)
      # Work out the class
      type_id = ((byte & 0xF0) >> 4)
      packet_class = MQTT::PACKET_TYPES[type_id]
      if packet_class.nil?
        raise ProtocolException, "Invalid packet type identifier: #{type_id}"
      end

      # Convert the last 4 bits of byte into array of true/false
      flags = (0..3).map { |i| byte & (2**i) != 0 }

      # Create a new packet object
      packet_class.new(:flags => flags)
    end

    # Create a new empty packet
    def initialize(args = {})
      # We must set flags before the other values
      @flags = [false, false, false, false]
      update_attributes(ATTR_DEFAULTS.merge(args))
    end

    # Set packet attributes from a hash of attribute names and values
    def update_attributes(attr = {})
      attr.each_pair do |k, v|
        if v.is_a?(Array) || v.is_a?(Hash)
          send("#{k}=", v.dup)
        else
          send("#{k}=", v)
        end
      end
    end

    # Get the identifer for this packet type
    def type_id
      index = MQTT::PACKET_TYPES.index(self.class)
      raise "Invalid packet type: #{self.class}" if index.nil?
      index
    end

    # Get the name of the packet type as a string in capitals
    # (like the MQTT specification uses)
    #
    # Example: CONNACK
    def type_name
      self.class.name.split('::').last.upcase
    end

    # Set the protocol version number
    def version=(arg)
      @version = arg.to_s
    end

    # Set the length of the packet body
    def body_length=(arg)
      @body_length = arg.to_i
    end

    # Parse the body (variable header and payload) of a packet
    def parse_body(buffer)
      return if buffer.bytesize == body_length

      raise ProtocolException, "Failed to parse packet - input buffer (#{buffer.bytesize}) is not the same as the body length header (#{body_length})"
    end

    # Get serialisation of packet's body (variable header and payload)
    def encode_body
      '' # No body by default
    end

    # Serialise the packet
    def to_s
      # Encode the fixed header
      header = [
        ((type_id.to_i & 0x0F) << 4) |
          (flags[3] ? 0x8 : 0x0) |
          (flags[2] ? 0x4 : 0x0) |
          (flags[1] ? 0x2 : 0x0) |
          (flags[0] ? 0x1 : 0x0)
      ]

      # Get the packet's variable header and payload
      body = encode_body

      # Check that that packet isn't too big
      body_length = body.bytesize
      if body_length > 268_435_455
        raise 'Error serialising packet: body is more than 256MB'
      end

      # Build up the body length field bytes
      loop do
        digit = (body_length % 128)
        body_length = body_length.div(128)
        # if there are more digits to encode, set the top bit of this digit
        digit |= 0x80 if body_length > 0
        header.push(digit)
        break if body_length <= 0
      end

      # Convert header to binary and add on body
      header.pack('C*') + body
    end

    # Check that fixed header flags are valid for types that don't use the flags
    # @private
    def validate_flags
      return if flags == [false, false, false, false]

      raise ProtocolException, "Invalid flags in #{type_name} packet header"
    end

    # Returns a human readable string
    def inspect
      "\#<#{self.class}>"
    end

    # Read and unpack a single byte from a socket
    def self.read_byte(socket)
      byte = socket.getbyte
      raise ProtocolException, 'Failed to read byte from socket' if byte.nil?

      byte
    end

    protected

    # Encode an array of bytes and return them
    def encode_bytes(*bytes)
      bytes.pack('C*')
    end

    # Encode an array of bits and return them
    def encode_bits(bits)
      [bits.map { |b| b ? '1' : '0' }.join].pack('b*')
    end

    # Encode a 16-bit unsigned integer and return it
    def encode_short(val)
      raise 'Value too big for short' if val > 0xffff
      [val.to_i].pack('n')
    end

    # Encode a UTF-8 string and return it
    # (preceded by the length of the string)
    def encode_string(str)
      str = str.to_s.encode('UTF-8')

      # Force to binary, when assembling the packet
      str.force_encoding('ASCII-8BIT')
      encode_short(str.bytesize) + str
    end

    # Remove a 16-bit unsigned integer from the front of buffer
    def shift_short(buffer)
      bytes = buffer.slice!(0..1)
      bytes.unpack('n').first
    end

    # Remove one byte from the front of the string
    def shift_byte(buffer)
      buffer.slice!(0...1).unpack('C').first
    end

    # Remove 8 bits from the front of buffer
    def shift_bits(buffer)
      buffer.slice!(0...1).unpack('b8').first.split('').map { |b| b == '1' }
    end

    # Remove n bytes from the front of buffer
    def shift_data(buffer, bytes)
      buffer.slice!(0...bytes)
    end

    # Remove string from the front of buffer
    def shift_string(buffer)
      len = shift_short(buffer)
      str = shift_data(buffer, len)
      # Strings in MQTT v3.1 are all UTF-8
      str.force_encoding('UTF-8')
    end

    # Encode a 32-bit unsigned integer (MQTT 5.0)
    def encode_int(val)
      raise 'Value too big for int' if val > 0xffffffff
      [val.to_i].pack('N')
    end

    # Remove a 32-bit unsigned integer from the front of buffer (MQTT 5.0)
    def shift_int(buffer)
      buffer.slice!(0..3).unpack1('N')
    end

    # Encode a variable byte integer (MQTT 5.0)
    def encode_variable_byte_integer(value)
      bytes = []
      loop do
        digit = value % 128
        value = value.div(128)
        digit |= 0x80 if value > 0
        bytes << digit
        break if value.zero?
      end
      bytes.pack('C*')
    end

    # Remove a variable byte integer from the front of buffer (MQTT 5.0)
    def shift_variable_byte_integer(buffer)
      multiplier = 1
      value = 0
      loop do
        byte = shift_byte(buffer)
        value += (byte & 0x7F) * multiplier
        break if (byte & 0x80).zero?
        multiplier *= 128
      end
      value
    end

    # Encode a string pair (MQTT 5.0 user properties)
    def encode_string_pair(key, value)
      encode_string(key) + encode_string(value)
    end

    # Remove a string pair from the front of buffer (MQTT 5.0)
    def shift_string_pair(buffer)
      key = shift_string(buffer)
      value = shift_string(buffer)
      [key, value]
    end

    # MQTT 5.0 Property identifiers
    PROPERTY_IDS = {
      payload_format_indicator: 0x01,
      message_expiry_interval: 0x02,
      content_type: 0x03,
      response_topic: 0x08,
      correlation_data: 0x09,
      subscription_identifier: 0x0B,
      session_expiry_interval: 0x11,
      assigned_client_identifier: 0x12,
      server_keep_alive: 0x13,
      authentication_method: 0x15,
      authentication_data: 0x16,
      request_problem_information: 0x17,
      will_delay_interval: 0x18,
      request_response_information: 0x19,
      response_information: 0x1A,
      server_reference: 0x1C,
      reason_string: 0x1F,
      receive_maximum: 0x21,
      topic_alias_maximum: 0x22,
      topic_alias: 0x23,
      maximum_qos: 0x24,
      retain_available: 0x25,
      user_property: 0x26,
      maximum_packet_size: 0x27,
      wildcard_subscription_available: 0x28,
      subscription_identifier_available: 0x29,
      shared_subscription_available: 0x2A
    }.freeze

    # Property types for encoding/decoding
    PROPERTY_TYPES = {
      0x01 => :byte,
      0x02 => :int,
      0x03 => :string,
      0x08 => :string,
      0x09 => :binary,
      0x0B => :variable_byte_integer,
      0x11 => :int,
      0x12 => :string,
      0x13 => :short,
      0x15 => :string,
      0x16 => :binary,
      0x17 => :byte,
      0x18 => :int,
      0x19 => :byte,
      0x1A => :string,
      0x1C => :string,
      0x1F => :string,
      0x21 => :short,
      0x22 => :short,
      0x23 => :short,
      0x24 => :byte,
      0x25 => :byte,
      0x26 => :string_pair,
      0x27 => :int,
      0x28 => :byte,
      0x29 => :byte,
      0x2A => :byte
    }.freeze

    # Reverse lookup: property ID to symbol
    PROPERTY_NAMES = PROPERTY_IDS.invert.freeze

    # Encode MQTT 5.0 properties hash to binary
    def encode_properties(properties)
      return encode_variable_byte_integer(0) if properties.nil? || properties.empty?

      data = ''.dup.force_encoding('ASCII-8BIT')
      properties.each do |key, value|
        prop_id = key.is_a?(Symbol) ? PROPERTY_IDS[key] : key
        raise "Unknown property: #{key}" if prop_id.nil?

        prop_type = PROPERTY_TYPES[prop_id]
        if key == :user_property || prop_id == 0x26
          # User properties can be repeated
          Array(value).each do |pair|
            data += encode_bytes(prop_id)
            data += encode_string_pair(pair[0], pair[1])
          end
        else
          data += encode_bytes(prop_id)
          data += encode_property_value(prop_type, value)
        end
      end

      encode_variable_byte_integer(data.bytesize) + data
    end

    # Parse MQTT 5.0 properties from buffer
    def parse_properties(buffer)
      return {} if buffer.empty?

      length = shift_variable_byte_integer(buffer)
      return {} if length.zero?

      prop_data = shift_data(buffer, length)
      properties = {}

      until prop_data.empty?
        prop_id = shift_byte(prop_data)
        prop_name = PROPERTY_NAMES[prop_id] || prop_id
        prop_type = PROPERTY_TYPES[prop_id]

        raise ProtocolException, "Unknown property identifier: #{prop_id}" if prop_type.nil?

        value = parse_property_value(prop_type, prop_data)

        if prop_id == 0x26 # user_property - can repeat
          properties[prop_name] ||= []
          properties[prop_name] << value
        else
          properties[prop_name] = value
        end
      end

      properties
    end

    # Encode a single property value based on type
    def encode_property_value(type, value)
      case type
      when :byte
        encode_bytes(value.to_i)
      when :short
        encode_short(value.to_i)
      when :int
        encode_int(value.to_i)
      when :string
        encode_string(value.to_s)
      when :binary
        encode_short(value.bytesize) + value.dup.force_encoding('ASCII-8BIT')
      when :variable_byte_integer
        encode_variable_byte_integer(value.to_i)
      when :string_pair
        encode_string_pair(value[0], value[1])
      else
        raise "Unknown property type: #{type}"
      end
    end

    # Parse a single property value based on type
    def parse_property_value(type, buffer)
      case type
      when :byte
        shift_byte(buffer)
      when :short
        shift_short(buffer)
      when :int
        shift_int(buffer)
      when :string
        shift_string(buffer)
      when :binary
        len = shift_short(buffer)
        shift_data(buffer, len)
      when :variable_byte_integer
        shift_variable_byte_integer(buffer)
      when :string_pair
        shift_string_pair(buffer)
      else
        raise "Unknown property type: #{type}"
      end
    end

    ## PACKET SUBCLASSES ##

    # Class representing an MQTT Publish message
    class Publish < MQTT::Packet
      # Duplicate delivery flag
      attr_accessor :duplicate

      # Retain flag
      attr_accessor :retain

      # Quality of Service level (0, 1, 2)
      attr_accessor :qos

      # The topic name to publish to
      attr_accessor :topic

      # The data to be published
      attr_accessor :payload

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Default attribute values
      ATTR_DEFAULTS = {
        :topic => nil,
        :payload => '',
        :properties => {}
      }

      # Create a new Publish packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      def duplicate
        @flags[3]
      end

      # Set the DUP flag (true/false)
      def duplicate=(arg)
        @flags[3] = arg.is_a?(Integer) ? (arg == 0x1) : arg
      end

      def retain
        @flags[0]
      end

      # Set the retain flag (true/false)
      def retain=(arg)
        @flags[0] = arg.is_a?(Integer) ? (arg == 0x1) : arg
      end

      def qos
        (@flags[1] ? 0x01 : 0x00) | (@flags[2] ? 0x02 : 0x00)
      end

      # Set the Quality of Service level (0/1/2)
      def qos=(arg)
        @qos = arg.to_i
        raise "Invalid QoS value: #{@qos}" if @qos < 0 || @qos > 2

        @flags[1] = (arg & 0x01 == 0x01)
        @flags[2] = (arg & 0x02 == 0x02)
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        if @topic.nil? || @topic.to_s.empty?
          raise 'Invalid topic name when serialising packet'
        end
        body += encode_string(@topic)
        body += encode_short(@id) unless qos.zero?
        body += encode_properties(@properties) if @version == '5.0'
        body += payload.to_s.dup.force_encoding('ASCII-8BIT')
        body
      end

      # Parse the body (variable header and payload) of a Publish packet
      def parse_body(buffer)
        super(buffer)
        @topic = shift_string(buffer)
        @id = shift_short(buffer) unless qos.zero?

        # MQTT 5.0: parse properties if version is set
        @properties = parse_properties(buffer) if @version == '5.0'

        @payload = buffer
      end

      # Check that fixed header flags are valid for this packet type
      # @private
      def validate_flags
        raise ProtocolException, 'Invalid packet: QoS value of 3 is not allowed' if qos == 3
        raise ProtocolException, 'Invalid packet: DUP cannot be set for QoS 0' if qos.zero? && duplicate
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: " \
          "d#{duplicate ? '1' : '0'}, " \
          "q#{qos}, " \
          "r#{retain ? '1' : '0'}, " \
          "m#{id}, " \
          "'#{topic}', " \
          "#{inspect_payload}>"
      end

      protected

      def inspect_payload
        str = payload.to_s
        if str.bytesize < 16 && str =~ /^[ -~]*$/
          "'#{str}'"
        else
          "... (#{str.bytesize} bytes)"
        end
      end
    end

    # Class representing an MQTT Connect Packet
    class Connect < MQTT::Packet
      # The name of the protocol
      attr_accessor :protocol_name

      # The version number of the protocol
      attr_accessor :protocol_level

      # The client identifier string
      attr_accessor :client_id

      # Set to false to keep a persistent session with the server
      attr_accessor :clean_session

      # Period the server should keep connection open for between pings
      attr_accessor :keep_alive

      # The topic name to send the Will message to
      attr_accessor :will_topic

      # The QoS level to send the Will message as
      attr_accessor :will_qos

      # Set to true to make the Will message retained
      attr_accessor :will_retain

      # The payload of the Will message
      attr_accessor :will_payload

      # The username for authenticating with the server
      attr_accessor :username

      # The password for authenticating with the server
      attr_accessor :password

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Default attribute values
      ATTR_DEFAULTS = {
        :client_id => nil,
        :clean_session => true,
        :keep_alive => 15,
        :will_topic => nil,
        :will_qos => 0,
        :will_retain => false,
        :will_payload => '',
        :username => nil,
        :password => nil,
        :properties => {}
      }

      # Create a new Client Connect packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))

        if ['3.1.0', '3.1'].include?(version)
          self.protocol_name ||= 'MQIsdp'
          self.protocol_level ||= 0x03
        elsif version == '3.1.1'
          self.protocol_name ||= 'MQTT'
          self.protocol_level ||= 0x04
        elsif version == '5.0'
          self.protocol_name ||= 'MQTT'
          self.protocol_level ||= 0x05
        else
          raise ArgumentError, "Unsupported protocol version: #{version}"
        end
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''

        if @version == '3.1.0'
          raise 'Client identifier too short while serialising packet' if @client_id.nil? || @client_id.bytesize < 1
          raise 'Client identifier too long when serialising packet' if @client_id.bytesize > 23
        end

        body += encode_string(@protocol_name)
        body += encode_bytes(@protocol_level.to_i)

        if @keep_alive < 0
          raise 'Invalid keep-alive value: cannot be less than 0'
        end

        # Set the Connect flags
        @connect_flags = 0
        @connect_flags |= 0x02 if @clean_session
        @connect_flags |= 0x04 unless @will_topic.nil?
        @connect_flags |= ((@will_qos & 0x03) << 3)
        @connect_flags |= 0x20 if @will_retain
        @connect_flags |= 0x40 unless @password.nil?
        @connect_flags |= 0x80 unless @username.nil?
        body += encode_bytes(@connect_flags)

        body += encode_short(@keep_alive)

        # MQTT 5.0: encode properties after keep_alive
        body += encode_properties(@properties) if @version == '5.0'

        body += encode_string(@client_id)
        unless will_topic.nil?
          body += encode_string(@will_topic)
          # The MQTT v3.1 specification says that the payload is a UTF-8 string
          body += encode_string(@will_payload)
        end
        body += encode_string(@username) unless @username.nil?
        body += encode_string(@password) unless @password.nil?
        body
      end

      # Parse the body (variable header and payload) of a Connect packet
      def parse_body(buffer)
        super(buffer)
        @protocol_name = shift_string(buffer)
        @protocol_level = shift_byte(buffer).to_i
        if @protocol_name == 'MQIsdp' && @protocol_level == 3
          @version = '3.1.0'
        elsif @protocol_name == 'MQTT' && @protocol_level == 4
          @version = '3.1.1'
        elsif @protocol_name == 'MQTT' && @protocol_level == 5
          @version = '5.0'
        else
          raise ProtocolException, "Unsupported protocol: #{@protocol_name}/#{@protocol_level}"
        end

        @connect_flags = shift_byte(buffer)
        @clean_session = ((@connect_flags & 0x02) >> 1) == 0x01
        @keep_alive = shift_short(buffer)

        # MQTT 5.0: parse properties after keep_alive
        @properties = parse_properties(buffer) if @version == '5.0'

        @client_id = shift_string(buffer)
        if ((@connect_flags & 0x04) >> 2) == 0x01
          # Last Will and Testament
          @will_qos = ((@connect_flags & 0x18) >> 3)
          @will_retain = ((@connect_flags & 0x20) >> 5) == 0x01
          @will_topic = shift_string(buffer)
          # The MQTT v3.1 specification says that the payload is a UTF-8 string
          @will_payload = shift_string(buffer)
        end
        if ((@connect_flags & 0x80) >> 7) == 0x01 && buffer.bytesize > 0
          @username = shift_string(buffer)
        end
        if ((@connect_flags & 0x40) >> 6) == 0x01 && buffer.bytesize > 0 # rubocop: disable Style/GuardClause
          @password = shift_string(buffer)
        end
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        str = "\#<#{self.class}: " \
              "keep_alive=#{keep_alive}"
        str += ', clean' if clean_session
        str += ", client_id='#{client_id}'"
        str += ", username='#{username}'" unless username.nil?
        str += ', password=...' unless password.nil?
        str + '>'
      end

      # ---- Deprecated attributes and methods  ---- #

      # @deprecated Please use {#protocol_level} instead
      def protocol_version
        protocol_level
      end

      # @deprecated Please use {#protocol_level=} instead
      def protocol_version=(args)
        self.protocol_level = args
      end
    end

    # Class representing an MQTT Connect Acknowledgment Packet
    class Connack < MQTT::Packet
      # Session Present flag
      attr_accessor :session_present

      # The return code (defaults to 0 for connection accepted)
      attr_accessor :return_code

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Default attribute values
      ATTR_DEFAULTS = { :return_code => 0x00, :properties => {} }

      # Create a new Client Connect packet
      def initialize(args = {})
        # We must set flags before other attributes
        @connack_flags = [false, false, false, false, false, false, false, false]
        super(ATTR_DEFAULTS.merge(args))
      end

      # Get the Session Present flag
      def session_present
        @connack_flags[0]
      end

      # Set the Session Present flag
      def session_present=(arg)
        @connack_flags[0] = arg.is_a?(Integer) ? (arg == 0x1) : arg
      end

      # Get a string message corresponding to a return code
      def return_msg
        case return_code
        when 0x00
          'Connection Accepted'
        when 0x01
          'Connection refused: unacceptable protocol version'
        when 0x02
          'Connection refused: client identifier rejected'
        when 0x03
          'Connection refused: server unavailable'
        when 0x04
          'Connection refused: bad user name or password'
        when 0x05
          'Connection refused: not authorised'
        else
          "Connection refused: error code #{return_code}"
        end
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        body += encode_bits(@connack_flags)
        body += encode_bytes(@return_code.to_i)
        body += encode_properties(@properties) if @version == '5.0'
        body
      end

      # Parse the body (variable header and payload) of a Connect Acknowledgment packet
      def parse_body(buffer)
        super(buffer)
        @connack_flags = shift_bits(buffer)
        unless @connack_flags[1, 7] == [false, false, false, false, false, false, false]
          raise ProtocolException, 'Invalid flags in Connack variable header'
        end
        @return_code = shift_byte(buffer)

        # MQTT 5.0: body_length >= 3 indicates properties are present
        # (3.1.1 Connack is always exactly 2 bytes: flags + return_code)
        if @body_length && @body_length >= 3
          @properties = parse_properties(buffer)
          @version = '5.0'
          return
        end

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Connect Acknowledgment packet'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % return_code
      end
    end

    # Class representing an MQTT Publish Acknowledgment packet
    class Puback < MQTT::Packet
      # MQTT 5.0 reason code (default 0x00 = success)
      attr_accessor :reason_code

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Get serialisation of packet's body
      def encode_body
        body = encode_short(@id)
        if @version == '5.0'
          body += encode_bytes(@reason_code || 0x00)
          body += encode_properties(@properties)
        end
        body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)

        # MQTT 5.0: body_length >= 3 means reason code and possibly properties
        if @body_length && @body_length >= 3
          @reason_code = shift_byte(buffer)
          @properties = parse_properties(buffer) unless buffer.empty?
          @version = '5.0'
          return
        end

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Publish Acknowledgment packet'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % id
      end
    end

    # Class representing an MQTT Publish Received packet
    class Pubrec < MQTT::Packet
      # MQTT 5.0 reason code (default 0x00 = success)
      attr_accessor :reason_code

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Get serialisation of packet's body
      def encode_body
        body = encode_short(@id)
        if @version == '5.0'
          body += encode_bytes(@reason_code || 0x00)
          body += encode_properties(@properties)
        end
        body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)

        # MQTT 5.0: body_length >= 3 means reason code and possibly properties
        if @body_length && @body_length >= 3
          @reason_code = shift_byte(buffer)
          @properties = parse_properties(buffer) unless buffer.empty?
          @version = '5.0'
          return
        end

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Publish Received packet'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % id
      end
    end

    # Class representing an MQTT Publish Release packet
    class Pubrel < MQTT::Packet
      # MQTT 5.0 reason code (default 0x00 = success)
      attr_accessor :reason_code

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Default attribute values
      ATTR_DEFAULTS = {
        :flags => [false, true, false, false]
      }

      # Create a new Pubrel packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        body = encode_short(@id)
        if @version == '5.0'
          body += encode_bytes(@reason_code || 0x00)
          body += encode_properties(@properties)
        end
        body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)

        # MQTT 5.0: body_length >= 3 means reason code and possibly properties
        if @body_length && @body_length >= 3
          @reason_code = shift_byte(buffer)
          @properties = parse_properties(buffer) unless buffer.empty?
          @version = '5.0'
          return
        end

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Publish Release packet'
      end

      # Check that fixed header flags are valid for this packet type
      # @private
      def validate_flags
        return if @flags == [false, true, false, false]
        raise ProtocolException, 'Invalid flags in PUBREL packet header'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % id
      end
    end

    # Class representing an MQTT Publish Complete packet
    class Pubcomp < MQTT::Packet
      # MQTT 5.0 reason code (default 0x00 = success)
      attr_accessor :reason_code

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Get serialisation of packet's body
      def encode_body
        body = encode_short(@id)
        if @version == '5.0'
          body += encode_bytes(@reason_code || 0x00)
          body += encode_properties(@properties)
        end
        body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)

        # MQTT 5.0: body_length >= 3 means reason code and possibly properties
        if @body_length && @body_length >= 3
          @reason_code = shift_byte(buffer)
          @properties = parse_properties(buffer) unless buffer.empty?
          @version = '5.0'
          return
        end

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Publish Complete packet'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % id
      end
    end

    # Class representing an MQTT Client Subscribe packet
    class Subscribe < MQTT::Packet
      # One or more topic filters to subscribe to
      attr_accessor :topics

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Default attribute values
      ATTR_DEFAULTS = {
        :topics => [],
        :flags => [false, true, false, false],
        :properties => {}
      }

      # Create a new Subscribe packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Set one or more topic filters for the Subscribe packet
      # The topics parameter should be one of the following:
      # * String: subscribe to one topic with QoS 0
      # * Array: subscribe to multiple topics with QoS 0
      # * Hash: subscribe to multiple topics where the key is the topic and the value is the QoS level
      #
      # For example:
      #   packet.topics = 'a/b'
      #   packet.topics = ['a/b', 'c/d']
      #   packet.topics = [['a/b',0], ['c/d',1]]
      #   packet.topics = {'a/b' => 0, 'c/d' => 1}
      #
      def topics=(value)
        # Get input into a consistent state
        input = value.is_a?(Array) ? value.flatten : [value]

        @topics = []
        until input.empty?
          item = input.shift
          if item.is_a?(Hash)
            # Convert hash into an ordered array of arrays
            @topics += item.sort
          elsif item.is_a?(String)
            # Peek at the next item in the array, and remove it if it is an integer
            if input.first.is_a?(Integer)
              qos = input.shift
              @topics << [item, qos]
            else
              @topics << [item, 0]
            end
          else
            # Meh?
            raise "Invalid topics input: #{value.inspect}"
          end
        end
        @topics
      end

      # Get serialisation of packet's body
      def encode_body
        raise 'no topics given when serialising packet' if @topics.empty?
        body = encode_short(@id)
        body += encode_properties(@properties) if @version == '5.0'
        topics.each do |item|
          body += encode_string(item[0])
          body += encode_bytes(item[1])
        end
        body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)
        @properties = parse_properties(buffer) if @version == '5.0'
        @topics = []
        while buffer.bytesize > 0
          topic_name = shift_string(buffer)
          topic_qos = shift_byte(buffer)
          @topics << [topic_name, topic_qos]
        end
      end

      # Check that fixed header flags are valid for this packet type
      # @private
      def validate_flags
        return if @flags == [false, true, false, false]
        raise ProtocolException, 'Invalid flags in SUBSCRIBE packet header'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        _str = "\#<#{self.class}: 0x%2.2X, %s>" % [
          id,
          topics.map { |t| "'#{t[0]}':#{t[1]}" }.join(', ')
        ]
      end
    end

    # Class representing an MQTT Subscribe Acknowledgment packet
    class Suback < MQTT::Packet
      # An array of return codes, ordered by the topics that were subscribed to
      attr_accessor :return_codes

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Default attribute values
      ATTR_DEFAULTS = {
        :return_codes => [],
        :properties => {}
      }

      # Create a new Subscribe Acknowledgment packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Set the granted QoS value for each of the topics that were subscribed to
      # Can either be an integer or an array or integers.
      def return_codes=(value)
        if value.is_a?(Array)
          @return_codes = value
        elsif value.is_a?(Integer)
          @return_codes = [value]
        else
          raise 'return_codes should be an integer or an array of return codes'
        end
      end

      # Get serialisation of packet's body
      def encode_body
        if @return_codes.empty?
          raise 'no granted QoS given when serialising packet'
        end
        body = encode_short(@id)
        body += encode_properties(@properties) if @version == '5.0'
        return_codes.each { |qos| body += encode_bytes(qos) }
        body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)
        @properties = parse_properties(buffer) if @version == '5.0'
        @return_codes << shift_byte(buffer) while buffer.bytesize > 0
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X, rc=%s>" % [id, return_codes.map { |rc| '0x%2.2X' % rc }.join(',')]
      end

      # ---- Deprecated attributes and methods  ---- #

      # @deprecated Please use {#return_codes} instead
      def granted_qos
        return_codes
      end

      # @deprecated Please use {#return_codes=} instead
      def granted_qos=(args)
        self.return_codes = args
      end
    end

    # Class representing an MQTT Client Unsubscribe packet
    class Unsubscribe < MQTT::Packet
      # One or more topic paths to unsubscribe from
      attr_accessor :topics

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Default attribute values
      ATTR_DEFAULTS = {
        :topics => [],
        :flags => [false, true, false, false],
        :properties => {}
      }

      # Create a new Unsubscribe packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Set one or more topic paths to unsubscribe from
      def topics=(value)
        @topics = value.is_a?(Array) ? value : [value]
      end

      # Get serialisation of packet's body
      def encode_body
        raise 'no topics given when serialising packet' if @topics.empty?
        body = encode_short(@id)
        body += encode_properties(@properties) if @version == '5.0'
        topics.each { |topic| body += encode_string(topic) }
        body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)
        @properties = parse_properties(buffer) if @version == '5.0'
        @topics << shift_string(buffer) while buffer.bytesize > 0
      end

      # Check that fixed header flags are valid for this packet type
      # @private
      def validate_flags
        return if @flags == [false, true, false, false]
        raise ProtocolException, 'Invalid flags in UNSUBSCRIBE packet header'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X, %s>" % [
          id,
          topics.map { |t| "'#{t}'" }.join(', ')
        ]
      end
    end

    # Class representing an MQTT Unsubscribe Acknowledgment packet
    class Unsuback < MQTT::Packet
      # MQTT 5.0 reason codes (one per topic)
      attr_accessor :reason_codes

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Default attribute values
      ATTR_DEFAULTS = {
        :reason_codes => [],
        :properties => {}
      }

      # Create a new Unsubscribe Acknowledgment packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        body = encode_short(@id)
        if @version == '5.0'
          body += encode_properties(@properties)
          @reason_codes.each { |rc| body += encode_bytes(rc) }
        end
        body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)

        # MQTT 5.0: body_length >= 3 means properties and reason codes
        if @body_length && @body_length >= 3
          @properties = parse_properties(buffer)
          @reason_codes = []
          @reason_codes << shift_byte(buffer) while buffer.bytesize > 0
          @version = '5.0'
          return
        end

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Unsubscribe Acknowledgment packet'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % id
      end
    end

    # Class representing an MQTT Ping Request packet
    class Pingreq < MQTT::Packet
      # Create a new Ping Request packet
      def initialize(args = {})
        super(args)
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Ping Request packet'
      end
    end

    # Class representing an MQTT Ping Response packet
    class Pingresp < MQTT::Packet
      # Create a new Ping Response packet
      def initialize(args = {})
        super(args)
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Ping Response packet'
      end
    end

    # Class representing an MQTT Client Disconnect packet
    class Disconnect < MQTT::Packet
      # MQTT 5.0 reason code (default 0x00 = normal disconnection)
      attr_accessor :reason_code

      # MQTT 5.0 properties hash
      attr_accessor :properties

      # Default attribute values
      ATTR_DEFAULTS = {
        :reason_code => 0x00,
        :properties => {}
      }

      # Create a new Client Disconnect packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        return '' unless @version == '5.0'
        body = encode_bytes(@reason_code || 0x00)
        body += encode_properties(@properties)
        body
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)

        # MQTT 5.0: body_length >= 1 means reason code present
        if @body_length && @body_length >= 1
          @reason_code = shift_byte(buffer)
          @properties = parse_properties(buffer) unless buffer.empty?
          @version = '5.0'
          return
        end

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Disconnect packet'
      end
    end

    # ---- Deprecated attributes and methods  ---- #
    public

    # @deprecated Please use {#id} instead
    def message_id
      id
    end

    # @deprecated Please use {#id=} instead
    def message_id=(args)
      self.id = args
    end
  end

  # An enumeration of the MQTT packet types
  PACKET_TYPES = [
    nil,
    MQTT::Packet::Connect,
    MQTT::Packet::Connack,
    MQTT::Packet::Publish,
    MQTT::Packet::Puback,
    MQTT::Packet::Pubrec,
    MQTT::Packet::Pubrel,
    MQTT::Packet::Pubcomp,
    MQTT::Packet::Subscribe,
    MQTT::Packet::Suback,
    MQTT::Packet::Unsubscribe,
    MQTT::Packet::Unsuback,
    MQTT::Packet::Pingreq,
    MQTT::Packet::Pingresp,
    MQTT::Packet::Disconnect,
    nil
  ]
end
