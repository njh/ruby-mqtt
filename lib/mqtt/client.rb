begin
  require "openssl"
rescue LoadError
end

# Client class for talking to an MQTT broker
class MQTT::Client
  attr_reader :remote_host     # Hostname of the remote broker
  attr_reader :remote_port     # Port number of the remote broker
  attr_accessor :keep_alive    # Time (in seconds) between pings to remote broker
  attr_accessor :clean_session # Set the 'Clean Session' flag when connecting?
  attr_accessor :client_id     # Client Identifier
  attr_accessor :ack_timeout   # Number of seconds to wait for acknowledgement packets
  attr_accessor :username      # Username to authenticate to the broker with
  attr_accessor :password      # Password to authenticate to the broker with
  attr_accessor :will_topic    # The topic that the Will message is published to
  attr_accessor :will_payload  # Contents of message that is sent by broker when client disconnect
  attr_accessor :will_qos      # The QoS level of the will message sent by the broker
  attr_accessor :will_retain   # If the Will message should be retain by the broker after it is sent
  attr_accessor :tls_cafile    # The path to a file containing a CA certificate
  attr_accessor :tls_certfile  # The path to a file containing the client's certificate
  attr_accessor :tls_keyfile   # The path to a file containing the client's private key

  # OLD deprecated clean_start
  alias :clean_start :clean_session
  alias :clean_start= :clean_session=

  # Timeout between select polls (in seconds)
  SELECT_TIMEOUT = 0.5

  # Default attribute values
  ATTR_DEFAULTS = {
    :remote_host => MQTT::DEFAULT_HOST,
    :remote_port => MQTT::DEFAULT_PORT,
    :keep_alive => 15,
    :clean_session => true,
    :client_id => nil,
    :ack_timeout => 5,
    :username => nil,
    :password => nil,
    :qos => 0,
    :will_topic => nil,
    :will_payload => nil,
    :will_qos => 0,
    :will_retain => false,
    :tls_cafile => nil,
    :tls_certfile => nil,
    :tls_keyfile => nil
  }

  # Create and connect a new MQTT Client
  # Accepts the same arguments as creating a new client.
  # If a block is given, then it will be executed before disconnecting again.
  #
  # Example:
  #  MQTT::Client.connect('myserver.example.com') do |client|
  #    # do stuff here
  #  end
  #
  def self.connect(*args, &block)
    client = MQTT::Client.new(*args)
    client.connect(&block)
    return client
  end

  # Generate a random client identifier
  # (using the characters 0-9 and a-z)
  def self.generate_client_id(prefix='ruby_', length=16)
    str = prefix.dup
    length.times do
      num = rand(36)
      if (num<10)
        # Number
        num += 48
      else
        # Letter
        num += 87
      end
      str += num.chr
    end
    return str
  end

  # Create a new MQTT Client instance
  #
  # Examples:
  #  client = MQTT::Client.new('myserver.example.com')
  #  client = MQTT::Client.new('myserver.example.com', 18830)
  #  client = MQTT::Client.new(:remote_host => 'myserver.example.com')
  #  client = MQTT::Client.new(:remote_host => 'myserver.example.com', :keep_alive => 30)
  #
  def initialize(*args)
    if args.length == 0
      args = {}
    elsif args.length == 1
      case args[0]
        when Hash
          args = args[0]
        when URI
          args = parse_uri(args[0])
        when %r|^mqtts?://|
          args = parse_uri(
            URI.parse(args[0])
          )
        else
          args = {:remote_host => args[0]}
      end
    elsif args.length == 1
      args = {:remote_host => args[0]}
    elsif args.length == 2
      args = {:remote_host => args[0], :remote_port => args[1]}
    else
      raise ArgumentError, "Unsupported number of arguments"
    end

    # Merge arguments with default values for attributes
    ATTR_DEFAULTS.merge(args).each_pair do |k,v|
      instance_variable_set("@#{k}", v)
    end

    # Initialise private instance variables
    @message_id = 0
    @last_pingreq = Time.now
    @last_pingresp = Time.now
    @socket = nil
    @read_queue = Queue.new
    @read_thread = nil
    @write_semaphore = Mutex.new
  end

  def set_will(topic, payload, retain=false, qos=0)
    self.will_topic = topic
    self.will_payload = payload
    self.will_retain = retain
    self.will_qos = qos
  end

  # Connect to the MQTT broker
  # If a block is given, then yield to that block and then disconnect again.
  def connect(clientid=nil,clean_session=false)
    if !clientid.nil?
      @client_id = clientid
      @clean_session = clean_session
    elsif @client_id.nil?
      @client_id = MQTT::Client.generate_client_id
      @clean_session = true
    end

    if not connected?
      # Create network socket
      tcp_socket = TCPSocket.new(@remote_host,@remote_port)

      if @tls_certfile.nil? || @tls_keyfile.nil?
        @socket = tcp_socket
      else
        raise 'openssl library not installed' unless defined?(OpenSSL)
        ssl_context = OpenSSL::SSL::SSLContext.new

        unless @tls_cafile.nil?
          ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
          ssl_context.ca_file = @tls_cafile
        end

        ssl_context.cert = OpenSSL::X509::Certificate.new(File.open(@tls_certfile))
        ssl_context.key  = OpenSSL::PKey::RSA.new(File.open(@tls_keyfile))

        @socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
        @socket.sync_close = true
        @socket.connect
      end

      ap @clean_session
      ap @client_id
      # Protocol name and version
      packet = MQTT::Packet::Connect.new(
        :clean_session => @clean_session,
        :keep_alive => @keep_alive,
        :client_id => @client_id,
        :username => @username,
        :password => @password,
        :qos      => @qos,
        :will_topic => @will_topic,
        :will_payload => @will_payload,
        :will_qos => @will_qos,
        :will_retain => @will_retain
      )

      # Send packet
      send_packet(packet)

      # Receive response
      receive_connack

      # Start packet reading thread
      @read_thread = Thread.new(Thread.current) do |parent|
        Thread.current[:parent] = parent
        loop { receive_packet }
      end
    end

    # If a block is given, then yield and disconnect
    if block_given?
      yield(self)
      disconnect
    end
  end

  # Disconnect from the MQTT broker.
  # If you don't want to say goodbye to the broker, set send_msg to false.
  def disconnect(send_msg=true)
    ap 'Good bye'
    if connected?
      if send_msg
        packet = MQTT::Packet::Disconnect.new
        send_packet(packet)
      end
      @socket.close unless @socket.nil?
      @socket = nil
    end
    @read_thread.kill if @read_thread and @read_thread.alive?
    @read_thread = nil
  end

  # Checks whether the client is connected to the broker.
  def connected?
    not @socket.nil?
  end

  # Send a MQTT ping message to indicate that the MQTT client is alive.
  def ping
    packet = MQTT::Packet::Pingreq.new
    send_packet(packet)
    @last_pingreq = Time.now
  end

  # Publish a message on a particular topic to the MQTT broker.
  def publish(topic, payload, retain=false, qos=0)
    packet = MQTT::Packet::Publish.new(
      :qos => qos,
      :retain => retain,
      :topic => topic,
      :payload => payload,
      :message_id => @message_id.next
    )

    # Send the packet
    send_packet(packet)
  end

  # Send a subscribe message for one or more topics on the MQTT broker.
  # The topics parameter should be one of the following:
  # * String: subscribe to one topic with QOS 0
  # * Array: subscribe to multiple topics with QOS 0
  # * Hash: subscribe to multiple topics where the key is the topic and the value is the QOS level
  #
  # For example:
  #   client.subscribe( 'a/b' )
  #   client.subscribe( 'a/b', 'c/d' )
  #   client.subscribe( ['a/b',0], ['c/d',1] )
  #   client.subscribe( 'a/b' => 0, 'c/d' => 1 )
  #
  def subscribe(*topics)
    packet = MQTT::Packet::Subscribe.new(
      :topics => topics,
      :message_id => @message_id.next
    )
    send_packet(packet)
  end

  # Return the next message received from the MQTT broker.
  # An optional topic can be given to subscribe to.
  #
  # The method either returns the topic and message as an array:
  #   topic,message = client.get
  #
  # Or can be used with a block to keep processing messages:
  #   client.get('test') do |topic,payload|
  #     # Do stuff here
  #   end
  #
  def get(topic=nil)
    # Subscribe to a topic, if an argument is given
    subscribe(topic) unless topic.nil?

    if block_given?
      # Loop forever!
      loop do
        packet = @read_queue.pop
        yield(packet.topic, packet.payload)
      end
    else
      # Wait for one packet to be available
      packet = @read_queue.pop
      return packet.topic, packet.payload
    end
  end

  # Return the next packet object received from the MQTT broker.
  # An optional topic can be given to subscribe to.
  #
  # The method either returns a single packet:
  #   packet = client.get_packet
  #   puts packet.topic
  #
  # Or can be used with a block to keep processing messages:
  #   client.get_packet('test') do |packet|
  #     # Do stuff here
  #     puts packet.topic
  #   end
  #
  def get_packet(topic=nil)
    # Subscribe to a topic, if an argument is given
    subscribe(topic) unless topic.nil?

    if block_given?
      # Loop forever!
      loop do
        yield(@read_queue.pop)
      end
    else
      # Wait for one packet to be available
      return @read_queue.pop
    end
  end

  # Returns true if the incoming message queue is empty.
  def queue_empty?
    @read_queue.empty?
  end

  # Returns the length of the incoming message queue.
  def queue_length
    @read_queue.length
  end

  # Send a unsubscribe message for one or more topics on the MQTT broker
  def unsubscribe(*topics)
    packet = MQTT::Packet::Unsubscribe.new(
      :topics => topics,
      :message_id => @message_id.next
    )
    send_packet(packet)
  end

private

  # Try to read a packet from the broker
  # Also sends keep-alive ping packets.
  def receive_packet
    begin
      # Poll socket - is there data waiting?
      return if @socket == nil
      result = IO.select([@socket], nil, nil, SELECT_TIMEOUT)
      unless result.nil?
        # Yes - read in the packet        
        packet = MQTT::Packet.read(@socket)        

        if packet.class == MQTT::Packet::Publish
          ap 'Publish ' + packet.qos.to_s

          qos_level = packet.qos

          if qos_level == 0
            # Add to queue
            @read_queue.push(packet)
          end

          if qos_level == 1
            data = MQTT::Packet::Puback.new(:message_id => packet.message_id)
            @write_semaphore.synchronize do
              @socket.write(data.to_s)
            end

            # Add to queue
            @read_queue.push(packet)
          end

          if qos_level == 2
            @last_packet = packet
            data = MQTT::Packet::Pubrec.new(:message_id => packet.message_id)
            @write_semaphore.synchronize do
              @socket.write(data.to_s)
            end
          end
        else
          if packet.class == MQTT::Packet::Puback or packet.class == MQTT::Packet::Pubrec or packet.class == MQTT::Packet::Pubcomp
            @last_ack = packet
            puts('Received ACK %d' % [@last_ack.type_id])
          end

          if packet.class == MQTT::Packet::Pubrel
            data = MQTT::Packet::Pubcomp.new(:message_id => packet.message_id)
            @write_semaphore.synchronize do
              @socket.write(data.to_s)
            end
            @read_queue.push(@last_packet)
          end
          # FIXME: implement responses for QOS 1 and 2
        end
      end

      # Time to send a keep-alive ping request?
      if @keep_alive > 0 and Time.now > @last_pingreq + @keep_alive
        ping
      end

      # FIXME: check we received a ping response recently?

    # Pass exceptions up to parent thread
    rescue Exception => exp
      ap 'Disconnecting'
      disconnect()
      unless @socket.nil?
        @socket.close
        @socket = nil
      end
      Thread.current[:parent].raise(exp)
    end
  end

  # Read and check a connection acknowledgement packet
  def receive_connack
    Timeout.timeout(@ack_timeout) do
      packet = MQTT::Packet.read(@socket)
      if packet.class != MQTT::Packet::Connack
        raise MQTT::ProtocolException.new("Response wan't a connection acknowledgement: #{packet.class}")
      end

      # Check the return code
      if packet.return_code != 0x00
        raise MQTT::ProtocolException.new(packet.return_msg)
      end
    end
  end

  # Send a packet to broker
  def send_packet(data)
    # Throw exception if we aren't connected
    raise MQTT::NotConnectedException if not connected?

    qos_level = data.qos
    if data.type_id != 3 or qos_level == 0
      # Only allow one thread to write to socket at a time
      ap [qos_level,data,data.to_hex] unless data.class == MQTT::Packet::Pingreq

      @write_semaphore.synchronize do
        @socket.write(data.to_s)
      end
    else
      ap 'Sending Publish with QOS = %d' % [qos_level]
      start_time = Time.now

      if qos_level == 1
        @last_ack = nil
        @write_semaphore.synchronize do
          @socket.write(data.to_s)
        end
        Timeout.timeout(@ack_timeout) do
          sleep(0.001) while @last_ack.nil?
        end
        raise 'Bad Protocol' if @last_ack.class != MQTT::Packet::Puback
        #ap 'RECEIVED ACK!!!'
      elsif qos_level == 2
        @last_ack = nil
        @write_semaphore.synchronize do
          @socket.write(data.to_s)
        end
        Timeout.timeout(@ack_timeout) do
          sleep(0.001) while @last_ack.nil?
        end
        raise 'Bad Protocol' if @last_ack.class != MQTT::Packet::Pubrec

        data = MQTT::Packet::Pubrel.new()
        @write_semaphore.synchronize do
          @socket.write(data.to_s)
        end
        @last_ack = nil
        Timeout.timeout(@ack_timeout) do
          sleep(0.001) while @last_ack.nil?
        end
        raise 'Bad Protocol' if @last_ack.class != MQTT::Packet::Pubcomp

      else
        raise 'Unexpected QOS Level'
      end

      end_time = Time.now
      printf("Message Received in: %.2f ms\n",(end_time - start_time) * 1000)
    end
  end

  private
  def parse_uri(uri)
    raise "Only the mqtt:// scheme is supported" unless uri.scheme == 'mqtt'

    {
      :remote_host => uri.host,
      :remote_port => uri.port || 1883,
      :username => uri.user,
      :password => uri.password
    }
  end

end
