module MQTT

  # Class representing a MQTT Packet
  # Performs binary encoding and decoding of headers
  class MQTT::Packet
    attr_reader :dup       # Duplicate delivery flag
    attr_reader :retain    # Retain flag
    attr_reader :qos       # Quality of Service level

    # Read in a packet from a socket
    def self.read(socket)
      # Read in the packet header and work out the class
      header = read_byte(socket)
      type_id = ((header & 0xF0) >> 4)
      packet_class = MQTT::PACKET_TYPES[type_id]

      # Create a new packet object
      packet = packet_class.new(
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
      packet.parse_body( socket.read(body_len) )

      return packet
    end

    # Create a new empty packet
    def initialize(args={})
      self.dup = args[:dup] || false
      self.qos = args[:qos] || 0
      self.retain = args[:retain] || false
    end

    # Get the identifer for this packet type
    def type_id
      index = MQTT::PACKET_TYPES.index(self.class)
      raise "Invalid packet type: #{self.class}" if index.nil?
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

    # Parse the body (variable header and payload) of a packet
    def parse_body(buffer)
      unless buffer.size == 0
        raise MQTT::ProtocolException.new("Error: parse_body was not sub-classed for a packet with a payload")
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
        ((dup ? 0x1 : 0x0) << 3) |
        ((qos.to_i & 0x03) << 1) |
        (retain ? 0x1 : 0x0)
      ]

      # Get the packet's variable header and payload
      body = self.encode_body

      # Build up the body length field bytes
      body_size = body.size
      begin
        digit = (body_size % 128)
        body_size = (body_size / 128)
        # if there are more digits to encode, set the top bit of this digit
        digit |= 0x80 if (body_size > 0)
        header.push(digit)
      end while (body_size > 0)

      # Convert header to binary and add on body
      header.pack('C*') + body
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

    # Encode a string and return it
    # (preceded by the length of the string)
    def encode_string(str)
      str = str.to_s unless str.is_a?(String)
      encode_short(str.size) + str
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
      shift_data(buffer,len)
    end


    private

    # Read and unpack a single byte from a socket
    def self.read_byte(socket)
      byte = socket.read(1)
      raise MQTT::ProtocolException if byte.nil?
      byte.unpack('C').first
    end



    ## PACKET SUBCLASSES ##


    # Class representing an MQTT Publish message
    class Publish < MQTT::Packet
      attr_accessor :topic
      attr_accessor :message_id
      attr_accessor :payload

      # Create a new Publish packet
      def initialize(args={})
        super(args)
        self.topic = args[:topic] || nil
        self.message_id = args[:message_id] || 0
        self.payload = args[:payload] || ''
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        raise "Invalid topic name when serialising packet" if @topic.nil?
        body += encode_string(@topic)
        body += encode_short(@message_id) unless qos == 0
        body += payload.to_s
        return body
      end

      # Parse the body (variable header and payload) of a Publish packet
      def parse_body(buffer)
        @topic = shift_string(buffer)
        @message_id = shift_short(buffer) unless qos == 0
        @payload = buffer.dup
      end
    end

    # Class representing an MQTT Connect Packet
    class Connect < MQTT::Packet
      attr_accessor :protocol_name
      attr_accessor :protocol_version
      attr_accessor :client_id
      attr_accessor :clean_start
      attr_accessor :keep_alive
      attr_accessor :will_topic
      attr_accessor :will_qos
      attr_accessor :will_retain
      attr_accessor :will_payload

      # Create a new Client Connect packet
      def initialize(args={})
        super(args)
        self.protocol_name = args[:protocol_name] || 'MQIsdp'
        self.protocol_version = args[:protocol_version] || 0x03
        self.client_id = args[:client_id] || nil
        self.clean_start = args[:clean_start] || true
        self.keep_alive = args[:keep_alive] || 10
        self.will_topic = args[:will_topic] || nil
        self.will_qos = args[:will_qos] || 0
        self.will_retain = args[:will_retain] || false
        self.will_payload = args[:will_payload] || ''
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        raise "Invalid client identifier when serialising packet" if @client_id.nil?
        body += encode_string(@protocol_name)
        body += encode_bytes(@protocol_version.to_i)
        body += encode_bytes(0) # Connect Flags
        body += encode_short(@keep_alive) # Keep Alive timer
        body += encode_string(@client_id)
        # FIXME: implement Will
        #unless @will_topic.nil?
        #  body += encode_string(@will_topic)
        #  body += will_payload.to_s
        #end
        return body
      end

      # Parse the body (variable header and payload) of a Connect packet
      def parse_body(buffer)
        @protocol_name = shift_string(buffer)
        @protocol_version = shift_byte(buffer)
        flags = shift_byte(buffer)
        @keep_alive = shift_short(buffer)
        @client_id = shift_string(buffer)
        # FIXME: implement Will
      end
    end

    # Class representing an MQTT Connect Acknowledgment Packet
    class Connack < MQTT::Packet
      attr_accessor :return_code

      # Create a new Client Connect packet
      def initialize(args={})
        super(args)
        self.return_code = args[:return_code] || 0
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
        unused = shift_byte(buffer)
        @return_code = shift_byte(buffer)
      end
    end

    # Class representing an MQTT Publish Acknowledgment packet
    class Puback < MQTT::Packet
      attr_accessor :message_id

      # Create a new Publish Acknowledgment packet
      def initialize(args={})
        super(args)
        self.message_id = args[:message_id] || 0
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@message_id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        @message_id = shift_short(buffer)
      end
    end

    # Class representing an MQTT Publish Received packet
    class Pubrec < MQTT::Packet
      attr_accessor :message_id

      # Create a new Publish Recieved packet
      def initialize(args={})
        super(args)
        self.message_id = args[:message_id] || 0
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@message_id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        @message_id = shift_short(buffer)
      end
    end

    # Class representing an MQTT Publish Release packet
    class Pubrel < MQTT::Packet
      attr_accessor :message_id

      # Create a new Publish Release packet
      def initialize(args={})
        super(args)
        self.message_id = args[:message_id] || 0
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@message_id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        @message_id = shift_short(buffer)
      end
    end

    # Class representing an MQTT Publish Complete packet
    class Pubcomp < MQTT::Packet
      attr_accessor :message_id

      # Create a new Publish Complete packet
      def initialize(args={})
        super(args)
        self.message_id = args[:message_id] || 0
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@message_id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        @message_id = shift_short(buffer)
      end
    end

    # Class representing an MQTT Client Subscribe packet
    class Subscribe < MQTT::Packet
      attr_reader :topics
      attr_accessor :message_id

      # Create a new Subscribe packet
      def initialize(args={})
        super(args)
        self.topics = args[:topics] || []
        self.message_id = args[:message_id] || 0
        self.qos = 1 # Force a QOS of 1
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
        while(input.size>0)
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
        raise "no topics given when serialising packet" if @topics.empty?
        body = encode_short(@message_id)
        topics.each do |item|
          body += encode_string(item[0])
          body += encode_bytes(item[1])
        end
        return body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        @message_id = shift_short(buffer)
        @topics = []
        while(buffer.size>0)
          topic_name = shift_string(buffer)
          topic_qos = shift_byte(buffer)
          @topics << [topic_name,topic_qos]
        end
      end
    end

    # Class representing an MQTT Subscribe Acknowledgment packet
    class Suback < MQTT::Packet
      attr_accessor :message_id
      attr_reader :granted_qos

      # Create a new Subscribe Acknowledgment packet
      def initialize(args={})
        super(args)
        self.message_id = args[:message_id] || 0
        self.granted_qos = args[:granted_qos] || []
      end

      def granted_qos=(value)
        raise "granted QOS should be an array of arrays" unless value.is_a?(Array)
        @granted_qos = value
      end

      # Get serialisation of packet's body
      def encode_body
        raise "no granted QOS given when serialising packet" if @granted_qos.empty?
        body = encode_short(@message_id)
        granted_qos.flatten.each { |qos| body += encode_bytes(qos) }
        return body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        @message_id = shift_short(buffer)
        while(buffer.size>0)
          @granted_qos << [shift_byte(buffer),shift_byte(buffer)]
        end
      end
    end

    # Class representing an MQTT Client Unsubscribe packet
    class Unsubscribe < MQTT::Packet
      attr_reader :topics
      attr_accessor :message_id

      # Create a new Unsubscribe packet
      def initialize(args={})
        super(args)
        self.topics = args[:topics] || []
        self.message_id = args[:message_id] || 0
        self.qos = 1 # Force a QOS of 1
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
        raise "no topics given when serialising packet" if @topics.empty?
        body = encode_short(@message_id)
        topics.each { |topic| body += encode_string(topic) }
        return body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        @message_id = shift_short(buffer)
        while(buffer.size>0)
          @topics << shift_string(buffer)
        end
      end
    end

    # Class representing an MQTT Unsubscribe Acknowledgment packet
    class Unsuback < MQTT::Packet
      attr_accessor :message_id

      # Create a new Unsubscribe Acknowledgment packet
      def initialize(args={})
        super(args)
        self.message_id = args[:message_id] || 0
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@message_id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        @message_id = shift_short(buffer)
      end
    end

    # Class representing an MQTT Ping Request packet
    class Pingreq < MQTT::Packet
      # Create a new Ping Request packet
      def initialize(args={})
        super(args)
      end
    end

    # Class representing an MQTT Ping Response packet
    class Pingresp < MQTT::Packet
      # Create a new Ping Response packet
      def initialize(args={})
        super(args)
      end
    end

    # Class representing an MQTT Client Disconnect packet
    class Disconnect < MQTT::Packet
      # Create a new Client Disconnect packet
      def initialize(args={})
        super(args)
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
