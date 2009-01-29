$:.unshift(File.dirname(__FILE__))

require 'spec_helper'
require 'mqtt/client'

describe MQTT::Client do

  before(:each) do
    @client = MQTT::Client.new
    @socket = StringIO.new
    @client.instance_variable_set(:@socket, @socket)
    @client.instance_variable_set(:@read_thread, stub_everything('Read Thread'))
  end
  
  describe "when calling the 'connect' method" do
  
  end
  
  describe "when calling the 'disconnect' method" do
    it "should not do anything if the socket is already disconnected"
  
    it "should write a valid DISCONNECT packet to the socket if the send_msg=true" do
      @client.disconnect(true)
      @socket.string.should == "\xE0\x00"
    end
    
    it "should not write anything to the socket if the send_msg=false" do
      @client.disconnect(false)
      @socket.string.should be_empty
    end
    
    it "should call the close method on the socket" do
      @socket.expects(:close)
      @client.disconnect
    end
  end
  
  describe "when calling the 'ping' method" do
    it "should write a valid PINGREQ packet to the socket" do
      @client.ping
      @socket.string.should == "\xC0\x00"
    end

    it "should update the time a ping was last sent" do
      @client.instance_variable_set(:@last_pingreq, 0)
      @client.ping
      @client.instance_variable_get(:@last_pingreq).should_not == 0
    end
  end
  
  describe "when calling the 'publish' method" do
    it "should write a valid PUBLISH packet to the socket without the detain flag" do
      @client.publish('topic','payload', false, 0)
      @socket.string.should == "\x30\x0e\x00\x05topicpayload"
    end
    
    it "should write a valid PUBLISH packet to the socket with the detain flag set" do
      @client.publish('topic','payload', true, 0)
      @socket.string.should == "\x31\x0e\x00\x05topicpayload"
    end
    
    it "should write a valid PUBLISH packet to the socket with the QOS set to 1" do
      @client.publish('topic','payload', false, 1)
      @socket.string.should == "\x32\x10\x00\x05topic\x00\x01payload"
    end
    
    it "should write a valid PUBLISH packet to the socket with the QOS set to 2" do
      @client.publish('topic','payload', false, 2)
      @socket.string.should == "\x34\x10\x00\x05topic\x00\x01payload"
    end
  end

  describe "when calling the 'subscribe' method" do
    it "should write a valid SUBSCRIBE packet with QoS 0 to the socket when given a single topic String" do
      @client.subscribe('a/b')
      @socket.string.should == "\x82\x08\x00\x01\x00\x03a/b\x00"
    end

    it "should write a valid SUBSCRIBE packet with QoS 0 to the socket when given a two topic Strings in an Array" do
      @client.subscribe('a/b','c/d')
      @socket.string.should == "\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x00"
    end

    it "should write a valid SUBSCRIBE packet to the socket when given a two topic Strings with QoS in an Array" do
      @client.subscribe(['a/b',0],['c/d',1])
      @socket.string.should == "\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x01"
    end

    it "should write a valid SUBSCRIBE packet to the socket when given a two topic Strings with QoS in a Hash" do
      @client.subscribe('a/b' => 0,'c/d' => 1)
      @socket.string.should == "\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x01"
    end
  end

  describe "when calling the 'get' method" do
    def inject_packet(topic, payload, opts={})
      opts[:type] = :publish
      packet = MQTT::Packet.new(opts)
      packet.add_string(topic)
      packet.add_short(2) unless packet.qos == 0
      packet.add_data(payload)
      @client.instance_variable_get('@read_queue').push(packet)
    end

    it "should successfull receive a valid PUBLISH packet with a QoS 0" do
      inject_packet('topic0','payload0', :qos => 0)
      topic,payload = @client.get
      topic.should == 'topic0'
      payload.should == 'payload0'
    end

    it "should successfull receive a valid PUBLISH packet with a QoS 1" do
      inject_packet('topic1','payload1', :qos => 1)
      topic,payload = @client.get
      topic.should == 'topic1'
      payload.should == 'payload1'
    end
  end

  describe "when calling the 'unsubscribe' method" do
    it "should write a valid UNSUBSCRIBE packet to the socket when given a single topic String" do
      @client.unsubscribe('a/b')
      @socket.string.should == "\xa2\x05\x00\x03a/b"
    end
    
    it "should write a valid UNSUBSCRIBE packet to the socket when given a two topic Strings" do
      @client.unsubscribe('a/b','c/d')
      @socket.string.should == "\xa2\x0a\x00\x03a/b\x00\x03c/d"
    end
  end
  
  
end
