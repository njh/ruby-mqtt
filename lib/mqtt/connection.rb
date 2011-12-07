
class MQTT::Connection < EventMachine::Connection

  attr_reader :state
  attr_reader :last_sent
  attr_reader :last_received

  def post_init
    @state = :connecting
    @last_sent = 0
    @last_received = 0
    @packet = nil
    @data = ''
  end

  # Checks whether a connection is full established
  def connected?
    state == :connected
  end

  def receive_data(data)
    @data << data

    # FIXME: limit maximum data / packet size

    # Are we at the start of a new packet?
    if @packet.nil? and @data.length >= 2
      @packet = MQTT::Packet.parse_header(@data)
    end

    # Do we have the the full packet body now?
    if @packet and @data.length >= @packet.body_length
      @packet.parse_body(
        @data.slice!(0...@packet.body_length)
      )
      @last_received = Time.now
      process_packet(@packet)
      @packet = nil
    end
  end
  
  # The function needs to be sub-classed
  def process_packet
  end
  
  def send_packet(packet)
    # FIXME: Throw exception if we aren't connected?
    #unless packet.class == MQTT::Packet::Connect
    #  raise MQTT::NotConnectedException if not connected?
    #end

    send_data(packet.to_s)
    @last_sent = Time.now
  end

end
