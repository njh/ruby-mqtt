$:.unshift(File.dirname(__FILE__))

require 'spec_helper'
require 'mqtt/client'

describe MQTT::Client do
  
  before(:each) do
    @client = MQTT::Client.new
    @socket = StringIO.new
    @client.instance_variable_set(:@socket, @socket)
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

  end

  describe "when calling the 'get' method" do

  end

  describe "when calling the 'unsubscribe' method" do

  end
  
  
end
