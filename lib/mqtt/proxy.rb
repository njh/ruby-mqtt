#!/usr/bin/env ruby

require 'mqtt'
require 'mqtt/packet'
require 'thread'
require 'logger'
require 'socket'


module MQTT

  # Class for implementing a MQTT proxy
  class Proxy
    attr_reader :local_host
    attr_reader :local_port
    attr_reader :broker_host
    attr_reader :broker_port
    attr_reader :listen_queue
    attr_reader :select_timeout
    attr_reader :logger
  
    # Create a new MQTT Proxy instance 
    # NOTE: be careful not to connect to yourself!
    def initialize(args={})
      @local_host = args[:local_host] || '0.0.0.0'
      @local_port = args[:local_port] || 1883
      @broker_host = args[:broker_host] || 'localhost'
      @broker_port = args[:broker_port] || 18830
      @listen_queue = args[:listen_queue] || 1
      @select_timeout = args[:select_timeout] || 60
      @logger = args[:logger] || Logger.new(STDOUT)
      
      # Create TCP server socket
      @server = TCPServer.open(@local_host,@local_port)
    end
    
    def add_downstream_proc
    
    end
    
    def add_upstream_proc
    
    end
    
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
            broker_socket.write(packet)
            logger.debug "client->broker (#{packet.type})"
          elsif selected[0].include?(broker_socket)
            packet = MQTT::Packet.read(broker_socket)
            client_socket.write(packet)
            logger.debug "broker->client (#{packet.type})"
          else
            logger.error "Problem with select: socket is neither broker or client"
          end
        end
      end
    end

  end
end