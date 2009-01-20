#!/usr/bin/env ruby

require 'mqtt'
require 'mqtt/packet'
require 'socket'


module MQTT

  # Client class for talking to an MQTT broker
  class Client
    attr_reader :remote_host, :remote_port

    # Create a new MQTT Client instance 
    def initialize(remote_host='localhost',remote_port=1883)
      @remote_host = remote_host
      @remote_port = remote_port
      @socket = nil
    end
    
    # Connect to the MQTT broker
    def connect(clientid)
      if not connected?
        @socket = TCPSocket.new(@remote_host,@remote_port)
        packet = MQTT::Packet.new(1)

        # Protocol name and version
        packet.add_string('MQIsdp')
        packet.add_bytes(0x03)
        
        # Connect flags (clean start)
        # FIXME: implement Will and Testament
        packet.add_bytes(0x02)
        
        # Keep Alive timer: 10 seconds
        packet.add_bytes(0x00,0x0a)
        
        # Add the client identifier
        packet.add_string(clientid)
        
        # Send packet
        @socket.write(packet)
      end
    end
    
    # Disconnect from the MQTT broker.
    def disconnect
      if connected?
        packet = MQTT::Packet.new(14)
        @socket.write(packet)
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
      packet = MQTT::Packet.new(12)
      @socket.write(packet)
    end

    # Publish a message on a particular topic to the MQTT broker.
    def publish(topic, message, qos=0, retained=false)
      packet = MQTT::Packet.new(3)
      packet.add_string(topic)
      
      # FIXME: add Message ID for qos1 and qos2
      raise "QOS 1 and 2 is currently unsupported" if qos!=0
      
      packet.add_data(message)
      
      @socket.write(packet)
    end
    
    #def register_handler
    
    # Subscribe to one or more topics.
    def subscribe(topics, qos)
    
    end
    
    def terminate(disconnect=false)
    
    end
    
    def unsubscribe(topics)
    
    end
  
  end

end
