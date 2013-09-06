# encoding: BINARY

module MQTT

  # Class representing a MQTT Packet
  # Performs binary encoding and decoding of headers
  class MQTT::Packet
    attr_reader :duplicate   # Duplicate delivery flag
    attr_reader :retain      # Retain flag
    attr_reader :qos         # Quality of Service level
    attr_reader :body_length # The length of the parsed packet body

    DEFAULTS = {
      :duplicate => false,
      :qos => 0,
      :retain => false,
      :body_length => nil
    }

    # Read in a packet from a socket
    def self.read(socket)
      # Read in the packet header and create a new packet object
      packet = create_from_header(
        read_byte(socket)
      )

      # Read in the packet length
      multiplier = 1
      body_length = 0
      pos = 1
      begin
        digit = read_byte(socket)
        body_length += ((digit & 0x7F) * multiplier)
        multiplier *= 0x80
        pos += 1
      end while ((digit & 0x80) != 0x00) and pos <= 4

      # Store the expected body length in the packet
      packet.instance_variable_set('@body_length', body_length)

      # Read in the packet body
      packet.parse_body( socket.read(body_length) )

      return packet
    end

    # Parse buffer into new packet object
    def self.parse(buffer)
      packet = parse_header(buffer)
      packet.parse_body(buffer)
      return packet
    end

    # Parse the header and create a new packet object of the correct type
    # The header is removed from the buffer passed into this function
    def self.parse_header(buffer)
      # Check that the packet is a long as the minimum packet size
      if buffer.bytesize < 2
        raise ProtocolException.new("Invalid packet: less than 2 bytes long")
      end

      # Create a new packet object
      bytes = buffer.unpack("C5")
      packet = create_from_header(bytes.first)

      # Parse the packet length
      body_length = 0
      multiplier = 1
      pos = 1
      begin
        if buffer.bytesize <= pos
          raise ProtocolException.new("The packet length header is incomplete")
        end
        digit = bytes[pos]
        body_length += ((digit & 0x7F) * multiplier)
        multiplier *= 0x80
        pos += 1
      end while ((digit & 0x80) != 0x00) and pos <= 4

      # Store the expected body length in the packet
      packet.instance_variable_set('@body_length', body_length)

      # Delete the fixed header from the raw packet passed in
      buffer.slice!(0...pos)

      return packet
    end

    # Create a new packet object from the first byte of a MQTT packet
    def self.create_from_header(byte)
      # Work out the class
      type_id = ((byte & 0xF0) >> 4)
      packet_class = MQTT::PACKET_TYPES[type_id]
      if packet_class.nil?
        raise ProtocolException.new("Invalid packet type identifier: #{type_id}")
      end

      # Create a new packet object
      packet_class.new(
        :duplicate => ((byte & 0x08) >> 3) == 0x01,
        :qos => ((byte & 0x06) >> 1),
        :retain => ((byte & 0x01) >> 0) == 0x01
      )
    end

    # Create a new empty packet
    def initialize(args={})
      update_attributes(DEFAULTS.merge(args))
    end

    def update_attributes(attr={})
      attr.each_pair do |k,v|
        send("#{k}=", v)
      end
    end

    # Get the identifer for this packet type
    def type_id
      index = MQTT::PACKET_TYPES.index(self.class)
      if index.nil?
        raise "Invalid packet type: #{self.class}"
      end
      return index
    end

    # Set the dup flag (true/false)
    def duplicate=(arg)
      if arg.kind_of?(Integer)
        @duplicate = (arg != 0)
      else
        @duplicate = arg
      end
    end

    # Set the retain flag (true/false)
    def retain=(arg)
      if arg.kind_of?(Integer)
        @retain = (arg != 0)
      else
        @retain = arg
      end
    end

    # Set the Quality of Service level (0/1/2)
    def qos=(arg)
      @qos = arg.to_i
      if @qos < 0 or @qos > 2
        raise "Invalid QoS value: #{@qos}"
      end
    end

    # Set the length of the packet body
    def body_length=(arg)
      @body_length = arg.to_i
    end

    # Parse the body (variable header and payload) of a packet
    def parse_body(buffer)
      if buffer.bytesize != body_length
        raise ProtocolException.new(
          "Failed to parse packet - input buffer (#{buffer.bytesize}) is not the same as the body length header (#{body_length})"
        )
      end
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
        ((duplicate ? 0x1 : 0x0) << 3) |
        ((qos.to_i & 0x03) << 1) |
        (retain ? 0x1 : 0x0)
      ]

      # Get the packet's variable header and payload
      body = self.encode_body

      # Check that that packet isn't too big
      body_length = body.bytesize
      if body_length > 268435455
        raise "Error serialising packet: body is more than 256MB"
      end

      # Build up the body length field bytes
      begin
        digit = (body_length % 128)
        body_length = (body_length / 128)
        # if there are more digits to encode, set the top bit of this digit
        digit |= 0x80 if (body_length > 0)
        header.push(digit)
      end while (body_length > 0)

      # Convert header to binary and add on body
      header.pack('C*') + body
    end

    def inspect
      "\#<#{self.class}>"
    end

    protected

    # Encode an array of bytes and return them
    def encode_bytes(*bytes)
      bytes.pack('C*')
    end

    # Encode a 16-bit unsigned integer and return it
    def encode_short(val)
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

    # Remove n bytes from the front of buffer
    def shift_data(buffer,bytes)
      buffer.slice!(0...bytes)
    end

    # Remove string from the front of buffer
    def shift_string(buffer)
      len = shift_short(buffer)
      str = shift_data(buffer,len)
      # Strings in MQTT v3.1 are all UTF-8
      str.force_encoding('UTF-8')
    end


    private

    # Read and unpack a single byte from a socket
    def self.read_byte(socket)
      byte = socket.read(1)
      if byte.nil?
        raise ProtocolException.new("Failed to read byte from socket")
      end
      byte.unpack('C').first
    end



    ## PACKET SUBCLASSES ##


    # Class representing an MQTT Publish message
    class Publish < MQTT::Packet
      attr_accessor :topic
      attr_accessor :message_id
      attr_accessor :payload

      DEFAULTS = {
          :topic => nil,
          :message_id => 0,
          :payload => ''
      }

      # Create a new Publish packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        if @topic.nil? or @topic.to_s.empty?
          raise "Invalid topic name when serialising packet"
        end
        body += encode_string(@topic)
        body += encode_short(@message_id) unless qos == 0
        body += payload.to_s.force_encoding('ASCII-8BIT')
        return body
      end

      # Parse the body (variable header and payload) of a Publish packet
      def parse_body(buffer)
        super(buffer)
        @topic = shift_string(buffer)
        @message_id = shift_short(buffer) unless qos == 0
        @payload = buffer
      end

      def inspect
        "\#<#{self.class}: " +
        "d#{duplicate ? '1' : '0'}, " +
        "q#{qos}, " +
        "r#{retain ? '1' : '0'}, " +
        "m#{message_id}, " +
        "'#{topic}', " +
        "#{inspect_payload}>"
      end

      protected
      def inspect_payload
        str = payload.to_s
        if str.bytesize < 16
          "'#{str}'"
        else
          "... (#{str.bytesize} bytes)"
        end
      end
    end

    # Class representing an MQTT Connect Packet
    class Connect < MQTT::Packet
      attr_accessor :protocol_name
      attr_accessor :protocol_version
      attr_accessor :client_id
      attr_accessor :clean_session
      attr_accessor :keep_alive
      attr_accessor :will_topic
      attr_accessor :will_qos
      attr_accessor :will_retain
      attr_accessor :will_payload
      attr_accessor :username
      attr_accessor :password

      # OLD deprecated clean_start
      alias :clean_start :clean_session
      alias :clean_start= :clean_session=

      DEFAULTS = {
        :protocol_name => 'MQIsdp',
        :protocol_version => 0x03,
        :client_id => nil,
        :clean_session => true,
        :keep_alive => 15,
        :will_topic => nil,
        :will_qos => 0,
        :will_retain => false,
        :will_payload => '',
        :username => nil,
        :password => nil,
      }

      # Create a new Client Connect packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        if @client_id.nil? or @client_id.bytesize < 1 or @client_id.bytesize > 23
          raise "Invalid client identifier when serialising packet"
        end
        body += encode_string(@protocol_name)
        body += encode_bytes(@protocol_version.to_i)

        if @keep_alive < 0
          raise "Invalid keep-alive value: cannot be less than 0"
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
        body += encode_string(@client_id)
        unless will_topic.nil?
          body += encode_string(@will_topic)
          # The MQTT v3.1 specification says that the payload is a UTF-8 string
          body += encode_string(@will_payload)
        end
        body += encode_string(@username) unless @username.nil?
        body += encode_string(@password) unless @password.nil?
        return body
      end

      # Parse the body (variable header and payload) of a Connect packet
      def parse_body(buffer)
        super(buffer)
        @protocol_name = shift_string(buffer)
        @protocol_version = shift_byte(buffer).to_i

        if @protocol_name != 'MQIsdp'
          raise ProtocolException.new(
            "Unsupported protocol name: #{@protocol_name}"
          )
        end

        if @protocol_version != 3
          raise ProtocolException.new(
            "Unsupported protocol version: #{@protocol_version}"
          )
        end

        @connect_flags = shift_byte(buffer)
        @clean_session = ((@connect_flags & 0x02) >> 1) == 0x01
        @keep_alive = shift_short(buffer)
        @client_id = shift_string(buffer)
        if ((@connect_flags & 0x04) >> 2) == 0x01
          # Last Will and Testament
          @will_qos = ((@connect_flags & 0x18) >> 3)
          @will_retain = ((@connect_flags & 0x20) >> 5) == 0x01
          @will_topic = shift_string(buffer)
          # The MQTT v3.1 specification says that the payload is a UTF-8 string
          @will_payload = shift_string(buffer)
        end
        if ((@connect_flags & 0x80) >> 7) == 0x01 and buffer.bytesize > 0
          @username = shift_string(buffer)
        end
        if ((@connect_flags & 0x40) >> 6) == 0x01 and buffer.bytesize > 0
          @password = shift_string(buffer)
        end
      end

      def inspect
        str = "\#<#{self.class}: "
        str += "keep_alive=#{keep_alive}"
        str += ", clean" if clean_session
        str += ", client_id='#{client_id}'"
        str += ", username='#{username}'" unless username.nil?
        str += ", password=..." unless password.nil?
        str += ">"
      end
    end

    # Class representing an MQTT Connect Acknowledgment Packet
    class Connack < MQTT::Packet
      attr_accessor :return_code
      DEFAULTS = {:return_code => 0x00}

      # Create a new Client Connect packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get a string message corresponding to a return code
      def return_msg
        case return_code
          when 0x00
            "Connection Accepted"
          when 0x01
            "Connection refused: unacceptable protocol version"
          when 0x02
            "Connection refused: client identifier rejected"
          when 0x03
            "Connection refused: broker unavailable"
          when 0x04
            "Connection refused: bad user name or password"
          when 0x05
            "Connection refused: not authorised"
          else
            "Connection refused: error code #{return_code}"
        end
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        body += encode_bytes(0) # Unused
        body += encode_bytes(@return_code.to_i) # Return Code
        return body
      end

      # Parse the body (variable header and payload) of a Connect Acknowledgment packet
      def parse_body(buffer)
        super(buffer)
        _unused = shift_byte(buffer)
        @return_code = shift_byte(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Connect Acknowledgment packet")
        end
      end

      def inspect
        "\#<#{self.class}: 0x%2.2X>" % return_code
      end
    end

    # Class representing an MQTT Publish Acknowledgment packet
    class Puback < MQTT::Packet
      attr_accessor :message_id
      DEFAULTS = {:message_id => 0}

      # Create a new Publish Acknowledgment packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@message_id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Publish Acknowledgment packet")
        end
      end

      def inspect
        "\#<#{self.class}: 0x%2.2X>" % message_id
      end
    end

    # Class representing an MQTT Publish Received packet
    class Pubrec < MQTT::Packet
      attr_accessor :message_id
      DEFAULTS = {:message_id => 0}

      # Create a new Publish Recieved packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@message_id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Publish Received packet")
        end
      end

      def inspect
        "\#<#{self.class}: 0x%2.2X>" % message_id
      end
    end

    # Class representing an MQTT Publish Release packet
    class Pubrel < MQTT::Packet
      attr_accessor :message_id
      DEFAULTS = {:message_id => 0}

      # Create a new Publish Release packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@message_id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Publish Release packet")
        end
      end

      def inspect
        "\#<#{self.class}: 0x%2.2X>" % message_id
      end
    end

    # Class representing an MQTT Publish Complete packet
    class Pubcomp < MQTT::Packet
      attr_accessor :message_id
      DEFAULTS = {:message_id => 0}

      # Create a new Publish Complete packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@message_id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Publish Complete packet")
        end
      end

      def inspect
        "\#<#{self.class}: 0x%2.2X>" % message_id
      end
    end

    # Class representing an MQTT Client Subscribe packet
    class Subscribe < MQTT::Packet
      attr_accessor :message_id
      attr_reader :topics
      DEFAULTS = {:message_id => 0}

      # Create a new Subscribe packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
        @topics ||= []
        @qos = 1 # Force a QOS of 1
      end

      # Set one or more topics for the Subscrible packet
      # The topics parameter should be one of the following:
      # * String: subscribe to one topic with QOS 0
      # * Array: subscribe to multiple topics with QOS 0
      # * Hash: subscribe to multiple topics where the key is the topic and the value is the QOS level
      #
      # For example:
      #   packet.topics = 'a/b'
      #   packet.topics = ['a/b', 'c/d']
      #   packet.topics = [['a/b',0], ['c/d',1]]
      #   packet.topics = {'a/b' => 0, 'c/d' => 1}
      #
      def topics=(value)
        # Get input into a consistent state
        if value.is_a?(Array)
          input = value.flatten
        else
          input = [value]
        end

        @topics = []
        while(input.length>0)
          item = input.shift
          if item.is_a?(Hash)
            # Convert hash into an ordered array of arrays
            @topics += item.sort
          elsif item.is_a?(String)
            # Peek at the next item in the array, and remove it if it is an integer
            if input.first.is_a?(Integer)
              qos = input.shift
              @topics << [item,qos]
            else
              @topics << [item,0]
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
        if @topics.empty?
          raise "no topics given when serialising packet"
        end
        body = encode_short(@message_id)
        topics.each do |item|
          body += encode_string(item[0])
          body += encode_bytes(item[1])
        end
        return body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        @topics = []
        while(buffer.bytesize>0)
          topic_name = shift_string(buffer)
          topic_qos = shift_byte(buffer)
          @topics << [topic_name,topic_qos]
        end
      end

      def inspect
        str = "\#<#{self.class}: 0x%2.2X, %s>" % [
          message_id,
          topics.map {|t| "'#{t[0]}':#{t[1]}"}.join(', ')
        ]
      end
    end

    # Class representing an MQTT Subscribe Acknowledgment packet
    class Suback < MQTT::Packet
      attr_accessor :message_id
      attr_reader :granted_qos
      DEFAULTS = {:message_id => 0}

      # Create a new Subscribe Acknowledgment packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
        @granted_qos ||= []
      end

      # Set the granted QOS value for each of the topics that were subscribed to
      # Can either be an integer or an array or integers.
      def granted_qos=(value)
        if value.is_a?(Array)
          @granted_qos = value
        elsif value.is_a?(Integer)
          @granted_qos = [value]
        else
          raise "granted QOS should be an integer or an array of QOS levels"
        end
      end

      # Get serialisation of packet's body
      def encode_body
        if @granted_qos.empty?
          raise "no granted QOS given when serialising packet"
        end
        body = encode_short(@message_id)
        granted_qos.each { |qos| body += encode_bytes(qos) }
        return body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        while(buffer.bytesize>0)
          @granted_qos << shift_byte(buffer)
        end
      end

      def inspect
        "\#<#{self.class}: 0x%2.2X, qos=%s>" % [message_id, granted_qos.join(',')]
      end
    end

    # Class representing an MQTT Client Unsubscribe packet
    class Unsubscribe < MQTT::Packet
      attr_reader :topics
      attr_accessor :message_id
      DEFAULTS = {:message_id => 0}

      # Create a new Unsubscribe packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
        @topics ||= []
        @qos = 1 # Force a QOS of 1
      end

      def topics=(value)
        if value.is_a?(Array)
          @topics = value
        else
          @topics = [value]
        end
      end

      # Get serialisation of packet's body
      def encode_body
        if @topics.empty?
          raise "no topics given when serialising packet"
        end
        body = encode_short(@message_id)
        topics.each { |topic| body += encode_string(topic) }
        return body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        while(buffer.bytesize>0)
          @topics << shift_string(buffer)
        end
      end

      def inspect
        str = "\#<#{self.class}: 0x%2.2X, %s>" % [
          message_id,
          topics.map {|t| "'#{t}'"}.join(', ')
        ]
      end
    end

    # Class representing an MQTT Unsubscribe Acknowledgment packet
    class Unsuback < MQTT::Packet
      attr_accessor :message_id
      DEFAULTS = {:message_id => 0}

      # Create a new Unsubscribe Acknowledgment packet
      def initialize(args={})
        super(DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@message_id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @message_id = shift_short(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Unsubscribe Acknowledgment packet")
        end
      end

      def inspect
        "\#<#{self.class}: 0x%2.2X>" % message_id
      end
    end

    # Class representing an MQTT Ping Request packet
    class Pingreq < MQTT::Packet
      # Create a new Ping Request packet
      def initialize(args={})
        super(args)
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Ping Request packet")
        end
      end
    end

    # Class representing an MQTT Ping Response packet
    class Pingresp < MQTT::Packet
      # Create a new Ping Response packet
      def initialize(args={})
        super(args)
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Ping Response packet")
        end
      end
    end

    # Class representing an MQTT Client Disconnect packet
    class Disconnect < MQTT::Packet
      # Create a new Client Disconnect packet
      def initialize(args={})
        super(args)
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)
        unless buffer.empty?
          raise ProtocolException.new("Extra bytes at end of Disconnect packet")
        end
      end
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
