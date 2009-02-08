#!/usr/bin/env ruby

require 'mqtt'
require 'mqtt/packet'
require 'thread'
require 'socket'
require 'timeout'


module MQTT

  # Client class for talking to an MQTT broker
  class Client
    attr_reader :remote_host    # Hostname of the remote broker
    attr_reader :remote_port    # Port number of the remote broker
    attr_accessor :keep_alive   # Time (in seconds) between pings to remote broker
    attr_accessor :clean_start  # Set the 'Clean Start' flag when connecting?
    attr_accessor :client_id    # Client Identifier
    attr_accessor :ack_timeout  # Number of seconds to wait for acknowledgement packets
    
    # Timeout between select polls (in seconds)
    SELECT_TIMEOUT = 0.5

    # Create a new MQTT Client instance 
    def initialize(remote_host='localhost', remote_port=1883)
      @remote_host = remote_host
      @remote_port = remote_port
      @keep_alive = 10
      @clean_start = true
      @client_id = random_letters(16)
      @message_id = 0
      @ack_timeout = 5
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
      @client_id = clientid unless clientid.nil?
    
      if not connected?
        # Create network socket
        @socket = TCPSocket.new(@remote_host,@remote_port)

        # Protocol name and version
        packet = MQTT::Packet.new(:type => :connect)
        packet.add_string('MQIsdp')
        packet.add_bytes(0x03)
        
        # Connect flags
        connect_flags = 0x00
        connect_flags ||= 0x02 if @clean_start
        # FIXME: implement Will and Testament
        packet.add_bytes(connect_flags)
        
        # Keep Alive timer: 10 seconds
        packet.add_short(@keep_alive)
        
        # Add the client identifier
        packet.add_string(@client_id)
        
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
          packet = MQTT::Packet.new(:type => :disconnect)
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
      packet = MQTT::Packet.new(:type => :pingreq)
      send_packet(packet)
      @last_pingreq = Time.now
    end

    # Publish a message on a particular topic to the MQTT broker.
    def publish(topic, payload, retain=false, qos=0)
      packet = MQTT::Packet.new(
        :type => :publish,
        :qos => qos,
        :retain => retain
      )
      
      # Add the topic name
      packet.add_string(topic)
      
      # Add Message ID for qos1 and qos2
      unless qos == 0
        packet.add_short(@message_id.next)
      end
      
      # Add the packet payload
      packet.add_data(payload)
      
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
      array = []
      topics.each do |item|
        if item.is_a?(Hash)
          # Convert hash into an ordered array of arrays
          array += item.sort
        elsif item.is_a?(Array)
          # Already in [topic,qos] format 
          array.push item
        else
          # Default to QOS 0
          array.push [item.to_s,0]
        end
      end
      
      # Create the packet
      packet = MQTT::Packet.new(:type => :subscribe, :qos => 1)
      packet.add_short(@message_id.next)
      array.each do |item|
        packet.add_string(item[0])
        packet.add_bytes(item[1])
      end
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
      
      # Parse the variable header
      topic = packet.shift_string
      msg_id = packet.shift_short unless (packet.qos == 0)
      return topic,packet.body
    end
    
    # Send a unsubscribe message for one or more topics on the MQTT broker
    def unsubscribe(*topics)
      packet = MQTT::Packet.new(:type => :unsubscribe, :qos => 1)
      topics.each { |topic| packet.add_string(topic) }
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
          if packet.type == :publish
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
        if packet.type != :connack
          raise MQTT::ProtocolException.new("Response wan't a connection acknowledgement: #{packet.type}") 
        end
        
        # Read in the return code
        byte1, return_code = packet.shift_bytes(2)
        if return_code == 0x00
          # Success
          nil
        elsif return_code == 0x01
          raise MQTT::ProtocolException.new("Connection refused: unacceptable protocol version")
        elsif return_code == 0x02
          raise MQTT::ProtocolException.new("Connection refused: client identifier rejected")
        elsif return_code == 0x03
          raise MQTT::ProtocolException.new("Connection refused: broker unavailable")
        else
          raise MQTT::ProtocolException.new("Connection refused: #{return_code}")
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

end
