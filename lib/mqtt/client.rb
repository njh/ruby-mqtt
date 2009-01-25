#!/usr/bin/env ruby

require 'mqtt'
require 'mqtt/packet'
require 'socket'


module MQTT

  # Client class for talking to an MQTT broker
  class Client
    attr_reader :remote_host    # Hostname of the remote broker
    attr_reader :remote_port    # Port number of the remote broker
    attr_accessor :keep_alive   # Time between pings to remote broker
    attr_accessor :clean_start  # Set the 'Clean Start' flag when connecting?
    
    # Timeout between select polls (in seconds)
    SELECT_TIMEOUT = 0.5

    # Create a new MQTT Client instance 
    def initialize(remote_host='localhost', remote_port=1883)
      @remote_host = remote_host
      @remote_port = remote_port
      @message_id = 0
      @keep_alive = 10
      @clean_start = true
      @last_pingreq = Time.now
      @last_pingresp = Time.now
      @socket = nil
    end
    
    # Connect to the MQTT broker
    # If a block is given, then yield to that block and then disconnect again.
    def connect(clientid)
      if not connected?
        @socket = TCPSocket.new(@remote_host,@remote_port)
        packet = MQTT::Packet.new(:type => :connect)

        # Protocol name and version
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
        packet.add_string(clientid)
        
        # Send packet
        @socket.write(packet)
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
          @socket.write(packet)
        end
        @socket.close
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
      @socket.write(packet)
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
      @socket.write(packet)
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
    #   client.subscribe( 'a/b' => 0 )
    #
    def subscribe(*topics)
      hash = {}
      topics.each do |item|
        if item.is_a?(Hash)
          hash.merge!(item)
        elsif item.is_a?(Array)
          # Default to QOS 0
          item.each { |i| hash[i] = 0 }
        else
          hash[item.to_s] = 0
        end
      end
      
      p hash
      
      # Create the packet
      packet = MQTT::Packet.new(:type => :subscribe, :qos => 1)
      packet.add_short(@message_id.next)
      hash.each_pair do |topic,qos|
        packet.add_string(topic)
        packet.add_bytes(qos)
      end
      @socket.write(packet)
    end
    
    # Return the next message recieved from the MQTT broker.
    # This method blocks until a message is available.
    # NOTE: It is currently necessary to keep calling this method in 
    # order to keep the connection to the broker alive.
    #
    # If you supply the optional block then the topic and message
    # will be passed to that block:
    #   client.get { |topic,message|  ... }
    #
    # The method also returns the topic and message:
    #   topic,message = client.get
    #
    def get
      loop do
        # Poll socket - is there data waiting?
        result = IO.select([@socket], nil, nil, SELECT_TIMEOUT)
        
        # Is there a packet waiting?
        unless result.nil?
          packet = MQTT::Packet.read(@socket)
          if packet.type == :publish
            # Parse the variable header
            topic = packet.shift_string
            msg_id = packet.shift_short unless (packet.qos == 0)
            payload = packet.body
            yield(topic,payload) if block_given?
            return topic,payload
          else
            # Ignore all other packets
            # FIXME: implement responses for QOS 1 and 2
          end
        end
        
        # Time to send a keep-alive ping request?
        if Time.now > @last_pingreq + @keep_alive
          ping
        end
        
        # FIXME: check we received a ping response recently?
        
      end
    end
    
    # Send a unsubscribe message for one or more topics on the MQTT broker
    def unsubscribe(*topics)
      packet = MQTT::Packet.new(:type => :unsubscribe, :qos => 1)
      topics.each { |topic| packet.add_string(topic) }
      @socket.write(packet)
    end
  
  end

end
