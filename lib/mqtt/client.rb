require 'set'
autoload :OpenSSL, 'openssl'


# Client class for talking to an MQTT broker
class MQTT::Client

  # Hostname of the remote broker
  attr_accessor :remote_host

  # Port number of the remote broker
  attr_accessor :remote_port

  # True to enable SSL/TLS encrypted communication
  attr_accessor :ssl

  # Time (in seconds) between pings to remote broker
  attr_accessor :keep_alive

  # Set the 'Clean Session' flag when connecting?
  attr_accessor :clean_session

  # Client Identifier
  attr_accessor :client_id

  # Number of seconds to wait for acknowledgement packets
  attr_accessor :ack_timeout

  # Username to authenticate to the broker with
  attr_accessor :username

  # Password to authenticate to the broker with
  attr_accessor :password

  # The topic that the Will message is published to
  attr_accessor :will_topic

  # Contents of message that is sent by broker when client disconnect
  attr_accessor :will_payload

  # The QoS level of the will message sent by the broker
  attr_accessor :will_qos

  # If the Will message should be retain by the broker after it is sent
  attr_accessor :will_retain

  # MQTT V3.1.1 version
  attr_accessor :v311

  # Reconnect after a dropped connection
  attr_accessor :reconnect

  # Timeout between select polls (in seconds)
  SELECT_TIMEOUT = 0.5

  # Default attribute values
  ATTR_DEFAULTS = {
    :remote_host => nil,
    :remote_port => nil,
    :keep_alive => 15,
    :clean_session => true,
    :client_id => nil,
    :ack_timeout => 5,
    :reconnect => false,
    :username => nil,
    :password => nil,
    :will_topic => nil,
    :will_payload => nil,
    :will_qos => 0,
    :will_retain => false,
    :v311  => false,
    :ssl => false
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
  # Accepts one of the following:
  # - a URI that uses the MQTT scheme
  # - a hostname and port
  # - a Hash containing attributes to be set on the new instance
  #
  # If no arguments are given then the method will look for a URI
  # in the MQTT_BROKER environment variable.
  #
  # Examples:
  #  client = MQTT::Client.new
  #  client = MQTT::Client.new('mqtt://myserver.example.com')
  #  client = MQTT::Client.new('mqtt://user:pass@myserver.example.com')
  #  client = MQTT::Client.new('myserver.example.com')
  #  client = MQTT::Client.new('myserver.example.com', 18830)
  #  client = MQTT::Client.new(:remote_host => 'myserver.example.com')
  #  client = MQTT::Client.new(:remote_host => 'myserver.example.com', :keep_alive => 30)
  #
  def initialize(*args)
    if args.last.is_a?(Hash)
      attr = args.pop
    else
      attr = {}
    end

    if args.length == 0
      if ENV['MQTT_BROKER']
        attr.merge!(parse_uri(ENV['MQTT_BROKER']))
      end
    end

    if args.length >= 1
      case args[0]
        when URI
          attr.merge!(parse_uri(args[0]))
        when %r|^mqtts?://|
          attr.merge!(parse_uri(args[0]))
        else
          attr.merge!(:remote_host => args[0])
      end
    end

    if args.length >= 2
      attr.merge!(:remote_port => args[1])
    end

    if args.length >= 3
      raise ArgumentError, "Unsupported number of arguments"
    end

    # Merge arguments with default values for attributes
    ATTR_DEFAULTS.merge(attr).each_pair do |k,v|
      self.send("#{k}=", v)
    end

    # Set a default port number
    if @remote_port.nil?
      @remote_port = @ssl ? MQTT::DEFAULT_SSL_PORT : MQTT::DEFAULT_PORT
    end

    # Initialise private instance variables
    @message_id = 0
    @last_pingreq = Time.now
    @last_pingresp = Time.now
    @socket = nil
    @read_queue = Queue.new
    @read_thread = nil
    @write_semaphore = Mutex.new

    @subscriptions = Set.new

    @expected_messages_out = {}
    @expected_messages_in = {}
  end

  # Get the OpenSSL context, that is used if SSL/TLS is enabled
  def ssl_context
    @ssl_context ||= OpenSSL::SSL::SSLContext.new
  end

  # Set a path to a file containing a PEM-format client certificate
  def cert_file=(path)
    ssl_context.cert = OpenSSL::X509::Certificate.new(File.open(path))
  end

  # Set a path to a file containing a PEM-format client private key
  def key_file=(path)
    ssl_context.key = OpenSSL::PKey::RSA.new(File.open(path))
  end

  # Set a path to a file containing a PEM-format CA certificate and enable peer verification
  def ca_file=(path)
    ssl_context.ca_file = path
    unless path.nil?
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
  end

  def set_will(topic, payload, retain=false, qos=0)
    self.will_topic = topic
    self.will_payload = payload
    self.will_retain = retain
    self.will_qos = qos
  end

  def send_connect_packet()
    # Protocol name and version
    packet = MQTT::Packet::Connect.new(
      :clean_session => @clean_session,
      :keep_alive => @keep_alive,
      :client_id => @client_id,
      :username => @username,
      :password => @password,
      :will_topic => @will_topic,
      :will_payload => @will_payload,
      :will_qos => @will_qos,
      :will_retain => @will_retain
    )

    if @v311
      packet.protocol_name = 'MQTT'
      packet.protocol_version = 0x4
    end

    # Send packet
    send_packet(packet)

    # Receive response
    receive_connack
  end

  # Connect to the MQTT broker
  # If a block is given, then yield to that block and then disconnect again.
  def connect(clientid=nil)
	unless clientid.nil?
      @client_id = clientid
    end

    if @client_id.nil? or @client_id.empty?
      if @clean_session
        @client_id = MQTT::Client.generate_client_id
      else
        raise 'Must provide a client_id if clean_session is set to false'
      end
    end

    if @remote_host.nil?
      raise 'No MQTT broker host set when attempting to connect'
    end

    if not connected?
      open_socket_connection()
      send_connect_packet()

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
  def disconnect(send_msg=true,wait_timeout=10)
    if connected?
      if send_msg
        begin
          timeout(wait_timeout) do
            while @expected_messages_out.keys.size > 0 or @expected_messages_in.keys.size > 0
              sleep 0.1
            end
          end
        rescue Timeout::Error
        end
        packet = MQTT::Packet::Disconnect.new
        send_packet(packet)
      end
      @socket.close unless @socket.nil?
      @socket = nil
    end

    kill_read_thread()
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
    raise MQTT::ProtocolException.new('Topic cannot contain wildcard characters') if topic =~ /[\*\+]/
    raise MQTT::ProtocolException.new('Invalid Topic size') if topic.bytesize > 65535
    raise MQTT::ProtocolException.new('Invalid Payload size') if payload.bytesize > 65535

    @message_id = @message_id.next
    packet = MQTT::Packet::Publish.new(
      :qos => qos,
      :retain => retain,
      :topic => topic,
      :payload => payload,
      :message_id => @message_id
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
    @message_id = @message_id.next
    packet = MQTT::Packet::Subscribe.new(
      :topics => topics,
      :message_id => @message_id
    )

    packet.topics.each do |topic|
      raise MQTT::ProtocolException.new('Invalid Topic size') if topic[0].bytesize > 65535
    end

    send_packet(packet)

    packet.topics.each do |topic|
      @subscriptions << topic[0]
    end
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

  def get_batch_messages topic=nil,sleep_time = 0.5,max_wait_time=10
    # Subscribe to a topic, if an argument is given
    subscribe(topic) unless topic.nil?


    start_time = Time.now.to_i
    sleep(sleep_time)
    messages = []

    loop do
      size = @read_queue.size

      break if messages.size > 0 and size == 0

      size.times do
        packet = @read_queue.pop(false)
        messages << [packet.topic,packet.payload]
      end

      break if Time.now.to_i - start_time > max_wait_time
      sleep(0.1)
    end
    return messages
  end

  # Send a unsubscribe message for one or more topics on the MQTT broker
  def unsubscribe(*topics)
    if topics.is_a?(Enumerable) and topics.count == 1
      topics = topics.first
    end

    @message_id = @message_id.next
    packet = MQTT::Packet::Unsubscribe.new(
      :topics => topics,
      :message_id => @message_id
    )

    packet.topics.each do |topic|
      raise MQTT::ProtocolException.new('Invalid Topic size') if topic.bytesize > 65535
    end

    packet.topics.each do |topic|
      @subscriptions.delete(topic)
    end

    send_packet(packet)
  end

private

  def open_socket_connection
    tcp_socket = TCPSocket.new(@remote_host, @remote_port)

    if @ssl
      @socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
      @socket.sync_close = true
      @socket.connect
    else
      @socket = tcp_socket
    end
  end

  def kill_read_thread
    @read_thread.kill if @read_thread and @read_thread.alive?
    @read_thread = nil
  end

  # Try to read a packet from the broker
  # Also sends keep-alive ping packets.
  def receive_packet
    begin
      # Poll socket - is there data waiting?
      begin
        if not connected? and @reconnect
          ap 'Reconnection'
          open_socket_connection()
          send_connect_packet()
          subscribe(@subscriptions.first) unless @subscriptions.empty?
        end

        result = IO.select([@socket], nil, nil, SELECT_TIMEOUT)
      rescue => err
        if @reconnect
          @socket = nil
          sleep 1
          return
        else
          raise err
        end
      end

      unless result.nil?
        # Yes - read in the packet
        begin
          packet = MQTT::Packet.read(@socket)
        rescue Exception => err
          if @reconnect
            @socket = nil
            sleep 1
            return
          else
            raise err
          end
        end
        if packet.class == MQTT::Packet::Publish
          message_id = packet.message_id

          if packet.qos == 0
            #nothing
          elsif packet.qos == 1
            ack_packet = MQTT::Packet::Puback.new(:message_id => message_id)
            send_packet(ack_packet)
          elsif packet.qos == 2
            ack_packet = MQTT::Packet::Pubrec.new(:message_id => message_id)
            send_packet(ack_packet)

            @expected_messages_in[message_id] = {:expected => MQTT::Packet::Pubrel.new(:message_id => message_id), :origin => ack_packet}
          end

          @read_queue.push(packet)
        end

        #Client => Server
        if packet.class == MQTT::Packet::Pubrec
          message_id = packet.message_id
          ack_packet = MQTT::Packet::Pubrel.new(:message_id => message_id)
          send_packet(ack_packet)
          @expected_messages_out[message_id] = {:expected => MQTT::Packet::Pubcomp.new(:message_id => message_id), :origin => ack_packet}
        end

        #Client => Server
        if packet.class == MQTT::Packet::Pubcomp or packet.class == MQTT::Packet::Puback
          message_id = packet.message_id

          process_last_message_ack(:outbound,message_id)
        end

        #Server => Client
        if packet.class == MQTT::Packet::Pubrel
          message_id = packet.message_id
          ack_packet = MQTT::Packet::Pubcomp.new(:message_id => message_id)
          send_packet(ack_packet)

          process_last_message_ack(:inbound,message_id)
        end
      end

      # Time to send a keep-alive ping request?
      if @keep_alive > 0 and Time.now > @last_pingreq + @keep_alive
        ping
      end

      # FIXME: check we received a ping response recently?

      # Time to verify expected messages
      process_unreceived_acks()

    # Pass exceptions up to parent thread
    rescue Exception => exp
      Thread.current[:parent].raise(exp)
      unless @socket.nil?
        @write_semaphore.synchronize do
          @socket.close
          @socket = nil
        end
      end
      kill_read_thread()
    end
  end

  def process_last_message_ack(message_direction,message_id)
    if message_direction == :inbound
      @expected_messages_in.delete(message_id)
    elsif message_direction == :outbound
      @expected_messages_out.delete(message_id)
    else
      raise 'Invalid message_direction'
    end
  end

  def process_unreceived_acks()
    resend_time = @keep_alive

    @expected_messages_in.each do |message_id,packets|
      packet = packets[:expected]
      origin = packets[:origin]

      if [MQTT::Packet::Publish,MQTT::Packet::Pubrec].include?(origin.class)
        diff_time = Time.now.to_i - packet.creation_timestamp
        #ap [diff_time,packet]

        if diff_time >= resend_time
          origin.duplicate = true#Duplicated message
          packet.creation_timestamp,origin.creation_timestamp = Time.now.to_i,Time.now.to_i
          send_packet(origin)
          @expected_messages_in[packet.message_id] = {:expected => packet,:origin => origin}
        end
      end
    end

    @expected_messages_out.each do |message_id,packets|
      packet = packets[:expected]
      origin = packets[:origin]

      if [MQTT::Packet::Publish,MQTT::Packet::Pubrec].include?(origin.class)
        diff_time = Time.now.to_i - packet.creation_timestamp
        #ap [diff_time,packet]

        if diff_time >= resend_time
          origin.duplicate = true#Duplicated message
          packet.creation_timestamp,origin.creation_timestamp = Time.now.to_i,Time.now.to_i
          send_packet(origin)
          @expected_messages_out[packet.message_id] = {:expected => packet,:origin => origin}
        end
      end
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
  def send_packet(packet)
    # Throw exception if we aren't connected
    if not connected?
      if @reconnect
        begin
          open_socket_connection()
          send_connect_packet()
        rescue
        end

        send_packet(packet)
        return
      else
        raise MQTT::NotConnectedException
      end
    end

    expected_packet_in  = nil
    expected_packet_out = nil
    if packet.class == MQTT::Packet::Publish
      if packet.qos == 1
        expected_packet_out = MQTT::Packet::Puback.new(:message_id => packet.message_id)
      elsif packet.qos == 2
        expected_packet_out = MQTT::Packet::Pubrec.new(:message_id => packet.message_id)
      end
    end

    if packet.class == MQTT::Packet::Pubrec
      expected_packet_in = MQTT::Packet::Pubrel.new(:message_id => packet.message_id)
    end

    if packet.class == MQTT::Packet::Pubrel
      expected_packet_out = MQTT::Packet::Pubcomp.new(:message_id => packet.message_id)
    end

    @expected_messages_in[expected_packet_in.message_id] =   {:expected=>expected_packet_in ,:origin => packet} unless expected_packet_in.nil?
    @expected_messages_out[expected_packet_out.message_id] = {:expected=>expected_packet_out,:origin => packet} unless expected_packet_out.nil?

    # Only allow one thread to write to socket at a time
    @write_semaphore.synchronize do
      @socket.write(packet.to_s)
    end
  end

   private
  def parse_uri(uri)
    uri = URI.parse(uri) unless uri.is_a?(URI)
    if uri.scheme == 'mqtt'
      ssl = false
    elsif uri.scheme == 'mqtts'
      ssl = true
    else
      raise "Only the mqtt:// and mqtts:// schemes are supported"
    end

    {
      :remote_host => uri.host,
      :remote_port => uri.port || nil,
      :username => uri.user,
      :password => uri.password,
      :ssl => ssl
    }
  end

end
