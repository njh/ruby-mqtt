# Class for implementing a proxy to filter/mangle MQTT packets.
class MQTT::Proxy
  # Address to bind listening socket to
  attr_reader :local_host

  # Port to bind listening socket to
  attr_reader :local_port
  
  # Address of upstream broker to send packets upstream to
  attr_reader :broker_host
  
  # Port of upstream broker to send packets upstream to.
  attr_reader :broker_port

  # Time in seconds before disconnecting an idle connection
  attr_reader :select_timeout
  
  # Ruby Logger object to send informational messages to
  attr_reader :logger

  # Create a new MQTT Proxy instance.
  #
  # Possible argument keys:
  #
  #  :local_host      Address to bind listening socket to.
  #  :local_port      Port to bind listening socket to.
  #  :broker_host     Address of upstream broker to send packets upstream to.
  #  :broker_port     Port of upstream broker to send packets upstream to.
  #  :select_timeout  Time in seconds before disconnecting a connection.
  #  :logger          Ruby Logger object to send informational messages to.
  #
  # NOTE: be careful not to connect to yourself!
  def initialize(args={})
    @local_host = args[:local_host] || '0.0.0.0'
    @local_port = args[:local_port] || MQTT::DEFAULT_PORT
    @broker_host = args[:broker_host]
    @broker_port = args[:broker_port] || 18830
    @select_timeout = args[:select_timeout] || 60

    # Setup a logger
    @logger = args[:logger]
    if @logger.nil?
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO
    end

    # Default is not to have any filters
    @client_filter = nil
    @broker_filter = nil

    # Create TCP server socket
    @server = TCPServer.open(@local_host,@local_port)
    @logger.info "MQTT::Proxy listening on #{@local_host}:#{@local_port}"
  end

  # Set a filter Proc for packets coming from the client (to the broker).
  def client_filter=(proc)
    @client_filter = proc
  end

  # Set a filter Proc for packets coming from the broker (to the client).
  def broker_filter=(proc)
    @broker_filter = proc
  end

  # Start accepting connections and processing packets.
  def run
    loop do
      # Wait for a client to connect and then create a thread for it
      Thread.new(@server.accept) do |client_socket|
        logger.info "Accepted client: #{client_socket.peeraddr.join(':')}"
        broker_socket = TCPSocket.new(@broker_host,@broker_port)
        begin
          process_packets(client_socket,broker_socket)
        rescue Exception => exp
          logger.error exp.to_s
        end
        logger.info "Disconnected: #{client_socket.peeraddr.join(':')}"
        broker_socket.close
        client_socket.close
      end
    end
  end

  private

  def process_packets(client_socket,broker_socket)
    loop do
      # Wait for some data on either socket
      selected = IO.select([client_socket,broker_socket], nil, nil, @select_timeout)
      if selected.nil?
        # Timeout
        raise "Timeout in select"
      else
        # Iterate through each of the sockets with data to read
        if selected[0].include?(client_socket)
          packet = MQTT::Packet.read(client_socket)
          logger.debug "client -> <#{packet.type}>"
          packet = @client_filter.call(packet) unless @client_filter.nil?
          unless packet.nil?
            broker_socket.write(packet)
            logger.debug "<#{packet.type}> -> broker"
          end
        elsif selected[0].include?(broker_socket)
          packet = MQTT::Packet.read(broker_socket)
          logger.debug "broker -> <#{packet.type}>"
          packet = @broker_filter.call(packet) unless @broker_filter.nil?
          unless packet.nil?
            client_socket.write(packet)
            logger.debug "<#{packet.type}> -> client"
          end
        else
          logger.error "Problem with select: socket is neither broker or client"
        end
      end
    end
  end

end
