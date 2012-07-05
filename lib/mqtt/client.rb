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
    :will_topic => nil,
    :will_payload => nil,
    :will_qos => 0,
    :will_retain => false
  }
  
  CALLBACKS = {
    :connack => nil,
    :suback => nil,
    :puback => nil,
    :pubrec => nil,
    :pubcomp => nil,
    :unsuback => nil,
    :message => nil
  }

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
    if args.count == 0
      args = {}
    elsif args.count == 1 and args[0].is_a?(Hash)
      args = args[0]
    elsif args.count == 1
      args = {:remote_host => args[0]}
    elsif args.count == 2
      args = {:remote_host => args[0], :remote_port => args[1]}
    elsif args.count == 3
      args = {:remote_host => args[0], :remote_port => args[1], :client_id => args[2]}
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
    @commands_queue = Queue.new
    @dispatcher = nil
    @write_semaphore = Mutex.new
    @subscribed_topics = {}
  end

  def set_will(topic, payload, retain=false, qos=0)
    self.will_topic = topic
    self.will_payload = payload
    self.will_retain = retain
    self.will_qos = qos
  end

  # Connect to the MQTT broker
  def connect
    
    if @client_id.nil?
      @client_id = MQTT::Client.generate_client_id
      @clean_session = true
    end
    
    # Create network socket
    @socket = TCPSocket.new(@remote_host,@remote_port)
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
    
    @dispatcher = Thread.new(Thread.current) do |parent|
      Thread.current[:parent] = parent
      loop {
        if connected?
          receive_packet
        end
        if !@commands_queue.empty?
          packet = @commands_queue.pop
          if ( packet.class == MQTT::Packet::Connack && !CALLBACKS[:connack].nil? )
            CALLBACKS[:connack].call()
          elsif ( packet.class == MQTT::Packet::Suback && !CALLBACKS[:suback].nil? )
            CALLBACKS[:suback].call( packet.granted_qos )
          elsif ( packet.class == MQTT::Packet::Puback && !CALLBACKS[:puback].nil? )
            CALLBACKS[:puback].call( packet.message_id )
          elsif ( packet.class == MQTT::Packet::Pubrec && !CALLBACKS[:pubrec].nil? )
            CALLBACKS[:pubrec].call( packet.message_id )
          elsif ( packet.class == MQTT::Packet::Pubcomp && !CALLBACKS[:pubcomp].nil? )
            CALLBACKS[:pubcomp].call( packet.message_id )
          elsif ( packet.class == MQTT::Packet::Unsuback && !CALLBACKS[:unsuback].nil? )
            CALLBACKS[:unsuback].call( packet )
          elsif ( packet.class == MQTT::Packet::Publish && !CALLBACKS[:message].nil? )
            CALLBACKS[:message].call( packet.topic, packet.payload, packet.qos, packet.message_id )
          else
            # puts "Command: #{packet.class}"
            nil
          end
        end
      }
    end
    
    send_packet(packet)
  
  end

  # Disconnect from the MQTT broker.
  # If you don't want to say goodbye to the broker, set send_msg to false.
  def disconnect(send_msg=true)
    if connected?
      if send_msg
        packet = MQTT::Packet::Disconnect.new
        send_packet(packet)
      end
      @socket.close unless @socket.nil?
      @socket = nil
    end
    @dispatcher.kill if @dispatcher and @dispatcher.alive?
    @dispatcher = nil
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
  	msg_id = nil
    if qos > 0
      msg_id = @message_id.next
    end
    packet = MQTT::Packet::Publish.new(
      :qos => qos,
      :retain => retain,
      :topic => topic,
      :payload => payload,
      :message_id => msg_id
    )
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
  def subscribe(*topics, &block)
    packet = MQTT::Packet::Subscribe.new(
      :topics => topics,
      :message_id => @message_id.next
    )
    send_packet(packet)
  end
  
  def pubrel(message_id)
    packet = MQTT::Packet::Pubrel.new(
      :message_id => message_id
    )
    send_packet(packet)
  end
  
  def unsubscribe(*topics)
    packet = MQTT::Packet::Unsubscribe.new(
      :topics => topics,
      :message_id => @message_id.next
    )
    send_packet(packet)
  end
  
  def on(action,&block)
    if ( !CALLBACKS.has_key?( action.to_sym ) )
      raise MQTT::UnknownEventException
    end
    CALLBACKS[action.to_sym] = block;
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
        if !@socket.nil?
          packet = MQTT::Packet.read(@socket)
          @commands_queue.push(packet)
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

  # Send a packet to broker
  def send_packet(data)
    # Throw exception if we aren't connected
    raise MQTT::NotConnectedException if not connected?
    # Only allow one thread to write to socket at a time
    @write_semaphore.synchronize do
      @socket.write(data)
    end
  end

end
