#!/usr/bin/env ruby
#
# This is a 'fake' MQTT server to help with testing client implementations
#
# It behaves in the following ways:
#   * Responses to CONNECT with a successful CONACK
#   * Responses to PUBLISH by echoing the packet back
#   * Responses to SUBSCRIBE with SUBACK and a PUBLISH to the topic
#   * Responses to PINGREQ with PINGRESP
#   * Responses to DISCONNECT by closing the socket
#
# It has the following restrictions
#   * Doesn't deal with timeouts
#   * Only handles a single connection at a time
#

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'logger'
require 'socket'
require 'mqtt'


class MQTT::TCFakeServer
  attr_reader :address, :port
  attr_reader :last_publish
  attr_reader :thread
  attr_reader :pings_received
  attr_accessor :just_one
  attr_accessor :logger

  # Create a new fake MQTT server
  #
  # If no port is given, bind to a random port number
  # If no bind address is given, bind to localhost
  def initialize(port=nil, bind_address='127.0.0.1')
    @port = port
    @address = bind_address
  end

  # Get the logger used by the server
  def logger
    @logger ||= Logger.new(STDOUT)
  end

  # Start the thread and open the socket that will process client connections
  def start
    @socket ||= TCPServer.new(@address, @port)
    @address = @socket.addr[3]
    @port = @socket.addr[1]
    @thread ||= Thread.new do
      logger.info "Started a fake TC MQTT server on #{@address}:#{@port}"
      loop do
        # Wait for a client to connect
        client = @socket.accept
        @pings_received = 0

        ap client
      end
    end
  end

  # Stop the thread and close the socket
  def stop
    logger.info "Stopping fake MQTT server"
    @socket.close unless @socket.nil?
    @socket = nil

    @thread.kill if @thread and @thread.alive?
    @thread = nil
  end

  # Start the server thread and wait for it to finish (possibly never)
  def run
    start
    begin
      @thread.join
    rescue Interrupt
      stop
    end
  end

end

if __FILE__ == $0
  server = MQTT::TCFakeServer.new(MQTT::DEFAULT_PORT)
  server.logger.level = Logger::DEBUG
  server.run
end
