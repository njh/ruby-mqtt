
class MQTT::ClientConnection < EventMachine::Connection
  include EventMachine::Deferrable

  attr_reader :state
  attr_reader :client_id
  attr_reader :keep_alive
  attr_reader :clean_start
  attr_reader :message_id
  attr_reader :ack_timeout
  attr_reader :timer
  attr_reader :last_sent
  attr_reader :last_received

  # FIXME: change this to optionally take hash of options
  def self.connect(host='localhost', port=1883, *args, &blk)
    EventMachine.connect( host, port, self, *args, &blk )
  end

  def post_init
    @state = :connecting
    @client_id = random_letters(16)
    @keep_alive = 10
    @clean_start = true
    @message_id = 0
    @ack_timeout = 5
    @timer = nil
    @last_sent = 0
    @last_received = 0
    @packet = nil
    @data = ''
  end

  def connection_completed
    # Protocol name and version
    packet = MQTT::Packet::Connect.new(
      :clean_start => @clean_start,
      :keep_alive => @keep_alive,
      :client_id => @client_id
    )

    send_packet(packet)

    @state = :connect_sent
  end

  # Checks whether the client is connected to the broker.
  def connected?
    state == :connected
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

  def receive_data(data)
    @data << data

    # Are we at the start of a new packet?
    if @packet.nil? and @data.length >= 2
      @packet = MQTT::Packet.parse_header(@data)
    end

    # Do we have the the full packet body now?
    if @packet and @data.length >= @packet.body_length
      @packet.parse_body(
        @data.slice!(0...@packet.body_length)
      )
      process_packet(@packet)
      @packet = nil
    end
  end
  
  # Disconnect from the MQTT broker.
  # If you don't want to say goodbye to the broker, set send_msg to false.
  def disconnect(send_msg=true)
    if connected?
      send_packet(MQTT::Packet::Disconnect.new) if send_msg
    end
    @state = :disconnecting
  end

  def receive_msg(message)
  end

  def unbind
    timer.cancel if timer
    unless state == :disconnecting
      raise MQTT::NotConnectedException.new("Connection to server lost")
    end
    @state = :disconnected
  end

  # Publish a message on a particular topic to the MQTT broker.
  def publish(topic, payload, retain=false, qos=0)
    # Defer publishing until we are connected
    callback do
      send_packet(
        MQTT::Packet::Publish.new(
          :qos => qos,
          :retain => retain,
          :topic => topic,
          :payload => payload,
          :message_id => @message_id.next
        )
      )
    end
  end

  # Send a subscribe message for one or more topics on the MQTT broker.
  def subscribe(*topics)
    # Defer subscribing until we are connected
    callback do
      send_packet(
        MQTT::Packet::Subscribe.new(
          :topics => topics,
          :message_id => @message_id.next
        )
      )
    end
  end

  # Send a unsubscribe message for one or more topics on the MQTT broker
  def unsubscribe(*topics)
    # Defer unsubscribing until we are connected
    callback do
      send_packet(
        MQTT::Packet::Unsubscribe.new(
          :topics => topics,
          :message_id => @message_id.next
        )
      )
    end
  end



private

  def process_packet(packet)
    @last_received = Time.now
    if state == :connect_sent and packet.class == MQTT::Packet::Connack
      connect_ack(packet)
    elsif state == :connected and packet.class == MQTT::Packet::Pingresp
      # Pong!
    elsif state == :connected and packet.class == MQTT::Packet::Publish
      receive_msg(packet)
    else
      # FIXME: deal with other packet types
      raise MQTT::ProtocolException.new(
        "Wasn't expecting packet of type #{packet.class} when in state #{state}"
      )
      disconnect
    end
  end
  
  def connect_ack(packet)
    if packet.return_code != 0x00
      raise MQTT::ProtocolException.new(packet.return_msg)
    else
      @state = :connected
    end
    
    # Send a ping packet every X seconds
    @timer = EventMachine::PeriodicTimer.new(keep_alive) do
      send_packet MQTT::Packet::Pingreq.new
    end
    
    # We are now connected - can now execute deferred calls
    set_deferred_success
  end

  def send_packet(packet)
    # Throw exception if we aren't connected
    unless packet.class == MQTT::Packet::Connect
      raise MQTT::NotConnectedException if not connected?
    end

    send_data(packet.to_s)
    @last_sent = Time.now
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
