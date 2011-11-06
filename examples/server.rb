#!/usr/bin/env ruby

require 'rubygems' # or use Bundler.setup
require 'mqtt'
require 'mqtt/packet'
require 'eventmachine'

class MQTT::Server < EM::Connection

  @@clients = Array.new

  attr_accessor :state
  attr_accessor :client_id
  attr_accessor :last_packet
  attr_accessor :keep_alive
  attr_accessor :message_id
  attr_accessor :subscriptions

  attr_reader :timer

  def post_init
    @state = :wait_connect
    @client_id = nil
    @last_packet = 0
    @keep_alive = 0
    @message_id = 0
    @subscriptions = []
    @timer = nil
  end

  def unbind
    @@clients.delete(self)
    @timer.cancel if @timer
  end

  def receive_data(data)
    # FIXME: re-factor so we don't need this buffer
    buffer = StringIO.new(data)
    # FIXME: cope with partial reads of large packets
    process_packet MQTT::Packet.read(buffer)
  end

  def process_packet(packet)
    puts "#{client_id}: #{packet.inspect}"
    self.last_packet = Time.now

    if state == :wait_connect and packet.class == MQTT::Packet::Connect
      connect(packet)
    elsif state == :connected and packet.class == MQTT::Packet::Pingreq
      ping(packet)
    elsif state == :connected and packet.class == MQTT::Packet::Subscribe
      subscribe(packet)
    elsif state == :connected and packet.class == MQTT::Packet::Publish
      publish(packet)
    elsif packet.class == MQTT::Packet::Disconnect
      puts "#{client_id} has disconnected"
      disconnect
    else
      # FIXME: deal with other packet types
      puts "Protocol Error."
      disconnect
    end
  end

  def connect(packet)
    # FIXME: check the protocol name and version
    self.client_id = packet.client_id
    send_packet MQTT::Packet::Connack.new
    self.state = :connected
    @@clients << self
    puts "#{client_id} is now connected"

    # Setup a keep-alive timer
    if packet.keep_alive
      @keep_alive = packet.keep_alive
      puts "#{client_id}: Setting keep alive timer to #{@keep_alive} seconds"
      @timer = EventMachine::PeriodicTimer.new(@keep_alive / 2) do
        last_seen = Time.now - @last_packet
        if last_seen > @keep_alive * 1.5
         puts "Disconnecting '#{client_id}' because it hasn't been seen for #{last_seen} seconds"
         disconnect
        end
      end
    end
  end

  def disconnect
    self.state = :disconnected
    close_connection
  end

  def ping(packet)
    send_packet MQTT::Packet::Pingresp.new
  end

  def subscribe(packet)
    packet.topics.each do |topic,qos|
      self.subscriptions << topic
    end
    puts "#{client_id} has subscriptions: #{self.subscriptions}"
    # FIXME: send subscribe acknowledgement?
  end

  def publish(packet)
    @@clients.each do |client|
      if client.subscriptions.include?(packet.topic) or client.subscriptions.include?('#')
        client.send_packet(packet)
      end
    end
  end

  def send_packet(packet)
    send_data(packet.to_s)
  end

end

EventMachine.run do
  # hit Control + C to stop
  Signal.trap("INT")  { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }

  EventMachine.start_server("0.0.0.0", 1883, MQTT::Server)
end
