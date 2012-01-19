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
    :password => nil
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

  # Create a new MQTT Client instance
  #
  # Examples:
  #  client = MQTT::Client.new('myserver.example.com')
  #  client = MQTT::Client.new('myserver.example.com', 18830)
  #  client = MQTT::Client.new(:remote_host => 'myserver.example.com')
  #  client = MQTT::Client.new(:remote_host => 'myserver.example.com', :keep_alive => 30)
  #
  def initialize(*args)
    if args.count == 0
      args = {}
    elsif args.count == 1 and args[0].is_a?(Hash)
      args = args[0]
    elsif args.count == 1
      args = {:remote_host => args[0]}
    elsif args.count == 2
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

  # Connect to the MQTT broker
  # If a block is given, then yield to that block and then disconnect again.
  def connect(clientid=nil)
    if !clientid.nil?
      @client_id = clientid
    elsif @clientid.nil?
      @client_id = random_letters(16)
      @clean_session = true
    end

    if not connected?
      # Create network socket
      @socket = TCPSocket.new(@remote_host,@remote_port)

      # Protocol name and version
      packet = MQTT::Packet::Connect.new(
        :clean_session => @clean_session,
        :keep_alive => @keep_alive,
        :client_id => @client_id,
        :username => @username,
        :password => @password
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
    if connected?
      if send_msg
        packet = MQTT::Packet::Disconnect.new
        send_packet(packet)
      end
      @read_thread.kill if @read_thread and @read_thread.alive?
      @read_thread = nil
      @socket.close unless @socket.nil?
      @socket = nil
    end
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

  # Return the next message recieved from the MQTT broker.
  # This method blocks until a message is available.
  #
  # The method returns the topic and message as an array:
  #   topic,message = client.get
  #
  def get
    # Wait for a packet to be available
    packet = @read_queue.pop
    topic = packet.topic
    payload = packet.payload
    return topic,payload
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
      result = IO.select([@socket], nil, nil, SELECT_TIMEOUT)
      unless result.nil?
        # Yes - read in the packet
        packet = MQTT::Packet.read(@socket)
        if packet.class == MQTT::Packet::Publish
          # Add to queue
          @read_queue.push(packet)
        else
          # Ignore all other packets
          nil
          # FIXME: implement responses for QOS 1 and 2
        end
      end

      # Time to send a keep-alive ping request?
      if Time.now > @last_pingreq + @keep_alive
        ping
      end

      # FIXME: check we received a ping response recently?

    # Pass exceptions up to parent thread
    rescue Exception => exp
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

    # Only allow one thread to write to socket at a time
    @write_semaphore.synchronize do
      @socket.write(data)
    end
  end

  # Generate a string of random letters (0-9,a-z)
  def random_letters(count)
    str = ''
    count.times do
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

end
