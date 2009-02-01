$:.unshift(File.dirname(__FILE__))

require 'spec_helper'
require 'mqtt/client'

describe MQTT::Client do

  before(:each) do
    @client = MQTT::Client.new
    @socket = StringIO.new
  end
  
  describe "when calling the 'connect' method" do
    before(:each) do
      TCPSocket.stubs(:new).returns(@socket)
      Thread.stubs(:new)
    end
    
    it "should create a TCP Socket if not connected" do
      TCPSocket.expects(:new).once.returns(@socket)
      @client.connect('myclient')
    end
    
    it "should not create a new TCP Socket if connected" do
      @client.stubs(:connected?).returns(true)
      TCPSocket.expects(:new).never
      @client.connect('myclient')
    end
    
    it "should start the reader thread if not connected" do
      Thread.expects(:new).once
      @client.connect('myclient')
    end
    
    it "should write a valid CONNECT packet to the socket if not connected" do
      @client.connect('myclient')
      @socket.string.should == "\020\026\x00\x06MQIsdp\x03\x00\x00\x0a\x00\x08myclient"
    end
    
    it "should disconnect after connecting, if a block is given" do
      @client.expects(:disconnect).once
      @client.connect('myclient') { nil }
    end
    
    it "should not disconnect after connecting, if no block is given" do
      @client.expects(:disconnect).never
      @client.connect('myclient')
    end
    
  end
  
  describe "when calling the 'disconnect' method" do
    before(:each) do
      @client.instance_variable_set(:@socket, @socket)
      @client.instance_variable_set(:@read_thread, stub_everything('Read Thread'))
    end
  
    it "should not do anything if the socket is already disconnected" do
      @client.stubs(:connected?).returns(false)
      @client.disconnect(true)
      @socket.string.should == ""
    end
  
    it "should write a valid DISCONNECT packet to the socket if connected and the send_msg=true an" do
      @client.stubs(:connected?).returns(true)
      @client.disconnect(true)
      @socket.string.should == "\xE0\x00"
    end
    
    it "should not write anything to the socket if the send_msg=false" do
      @client.stubs(:connected?).returns(true)
      @client.disconnect(false)
      @socket.string.should be_empty
    end
    
    it "should call the close method on the socket" do
      @socket.expects(:close)
      @client.disconnect
    end
  end
  
  describe "when calling the 'ping' method" do
    before(:each) do
      @client.instance_variable_set(:@socket, @socket)
    end

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
    before(:each) do
      @client.instance_variable_set(:@socket, @socket)
    end

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
    before(:each) do
      @client.instance_variable_set(:@socket, @socket)
    end

    it "should write a valid SUBSCRIBE packet with QoS 0 to the socket if given a single topic String" do
      @client.subscribe('a/b')
      @socket.string.should == "\x82\x08\x00\x01\x00\x03a/b\x00"
    end

    it "should write a valid SUBSCRIBE packet with QoS 0 to the socket if given a two topic Strings in an Array" do
      @client.subscribe('a/b','c/d')
      @socket.string.should == "\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x00"
    end

    it "should write a valid SUBSCRIBE packet to the socket if given a two topic Strings with QoS in an Array" do
      @client.subscribe(['a/b',0],['c/d',1])
      @socket.string.should == "\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x01"
    end

    it "should write a valid SUBSCRIBE packet to the socket if given a two topic Strings with QoS in a Hash" do
      @client.subscribe('a/b' => 0,'c/d' => 1)
      @socket.string.should == "\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x01"
    end
  end

  describe "when calling the 'get' method" do
    before(:each) do
      @client.instance_variable_set(:@socket, @socket)
    end

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
    before(:each) do
      @client.instance_variable_set(:@socket, @socket)
    end

    it "should write a valid UNSUBSCRIBE packet to the socket if given a single topic String" do
      @client.unsubscribe('a/b')
      @socket.string.should == "\xa2\x05\x00\x03a/b"
    end
    
    it "should write a valid UNSUBSCRIBE packet to the socket if given a two topic Strings" do
      @client.unsubscribe('a/b','c/d')
      @socket.string.should == "\xa2\x0a\x00\x03a/b\x00\x03c/d"
    end
  end
  
  describe "when calling the 'receive_packet' method" do
    before(:each) do
      @client.instance_variable_set(:@socket, @socket)
      IO.stubs(:select).returns([[@socket], [], []])
      @read_queue = @client.instance_variable_get(:@read_queue)
      @parent_thread = Thread.current[:parent] = stub_everything('Parent Thread')
    end

    it "should put PUBLISH messages on to the read queue" do
      @socket.write("\x30\x0e\x00\x05topicpayload")
      @socket.rewind
      @client.send(:receive_packet)
      @read_queue.size.should == 1
    end

    it "should not put other messages on to the read queue" do
      @socket.write("\x20\x02\x00\x00")
      @socket.rewind
      @client.send(:receive_packet)
      @read_queue.size.should == 0
    end
    
    it "should send a ping packet if one is due" do
      IO.expects(:select).returns(nil)
      @client.instance_variable_set(:@last_pingreq, Time.at(0))
      @client.expects(:ping).once
      @client.send(:receive_packet)
    end

    it "should close the socket if there is an exception" do
      @socket.expects(:close).once
      MQTT::Packet.stubs(:read).raises(MQTT::Exception)
      @client.send(:receive_packet)
    end

    it "should pass exceptions up to parent thread" do
      @parent_thread.expects(:raise).once
      MQTT::Packet.stubs(:read).raises(MQTT::Exception)
      @client.send(:receive_packet)
    end
    
  end
  
end
