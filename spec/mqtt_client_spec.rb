# encoding: BINARY
# Encoding is set to binary, so that the binary packets aren't validated as UTF-8

$:.unshift(File.dirname(__FILE__))

require 'spec_helper'
require 'mqtt'

describe MQTT::Client do

  before(:each) do
    # Reset environment variable
    ENV.delete('MQTT_BROKER')
  end

  let(:client) { MQTT::Client.new(:remote_host => 'localhost') }
  let(:socket) do
    socket = StringIO.new
    if socket.respond_to?(:set_encoding)
      socket.set_encoding("binary")
    else
      socket
    end
  end

  describe "initializing a client" do
    it "with no arguments, it should use the defaults" do
      client = MQTT::Client.new
      client.remote_host.should == nil
      client.remote_port.should == 1883
      client.keep_alive.should == 15
    end

    it "with a single string argument, it should use it has the host" do
      client = MQTT::Client.new('otherhost.mqtt.org')
      client.remote_host.should == 'otherhost.mqtt.org'
      client.remote_port.should == 1883
      client.keep_alive.should == 15
    end

    it "with two arguments, it should use it as the host and port" do
      client = MQTT::Client.new('otherhost.mqtt.org', 1000)
      client.remote_host.should == 'otherhost.mqtt.org'
      client.remote_port.should == 1000
      client.keep_alive.should == 15
    end

    it "with names arguments, it should use those as arguments" do
      client = MQTT::Client.new(:remote_host => 'otherhost.mqtt.org', :remote_port => 1000)
      client.remote_host.should == 'otherhost.mqtt.org'
      client.remote_port.should == 1000
      client.keep_alive.should == 15
    end

    it "with a hash, it should use those as arguments" do
      client = MQTT::Client.new({:remote_host => 'otherhost.mqtt.org', :remote_port => 1000})
      client.remote_host.should == 'otherhost.mqtt.org'
      client.remote_port.should == 1000
      client.keep_alive.should == 15
    end

    it "with a hash containing just a keep alive setting" do
      client = MQTT::Client.new(:remote_host => 'localhost', :keep_alive => 60)
      client.remote_host.should == 'localhost'
      client.remote_port.should == 1883
      client.keep_alive.should == 60
    end

    it "with a combination of a host name and a hash of settings" do
      client = MQTT::Client.new('localhost', :keep_alive => 65)
      client.remote_host.should == 'localhost'
      client.remote_port.should == 1883
      client.keep_alive.should == 65
    end

    it "with a combination of a host name, port and a hash of settings" do
      client = MQTT::Client.new('localhost', 1888, :keep_alive => 65)
      client.remote_host.should == 'localhost'
      client.remote_port.should == 1888
      client.keep_alive.should == 65
    end

    it "with a mqtt:// URI containing just a hostname" do
      client = MQTT::Client.new(URI.parse('mqtt://mqtt.example.com'))
      client.remote_host.should == 'mqtt.example.com'
      client.remote_port.should == 1883
      client.ssl.should be_false
    end

    it "with a mqtts:// URI containing just a hostname" do
      client = MQTT::Client.new(URI.parse('mqtts://mqtt.example.com'))
      client.remote_host.should == 'mqtt.example.com'
      client.remote_port.should == 8883
      client.ssl.should be_true
    end

    it "with a mqtt:// URI containing a custom port number" do
      client = MQTT::Client.new(URI.parse('mqtt://mqtt.example.com:1234/'))
      client.remote_host.should == 'mqtt.example.com'
      client.remote_port.should == 1234
      client.ssl.should be_false
    end

    it "with a mqtts:// URI containing a custom port number" do
      client = MQTT::Client.new(URI.parse('mqtts://mqtt.example.com:1234/'))
      client.remote_host.should == 'mqtt.example.com'
      client.remote_port.should == 1234
      client.ssl.should be_true
    end

    it "with a URI containing a username and password" do
      client = MQTT::Client.new(URI.parse('mqtt://auser:bpass@mqtt.example.com'))
      client.remote_host.should == 'mqtt.example.com'
      client.remote_port.should == 1883
      client.username.should == 'auser'
      client.password.should == 'bpass'
    end

    it "with a URI as a string" do
      client = MQTT::Client.new('mqtt://mqtt.example.com')
      client.remote_host.should == 'mqtt.example.com'
      client.remote_port.should == 1883
    end

    it "with a URI and a hash of settings" do
      client = MQTT::Client.new('mqtt://mqtt.example.com', :keep_alive => 65)
      client.remote_host.should == 'mqtt.example.com'
      client.remote_port.should == 1883
      client.keep_alive.should == 65
    end

    it "with no arguments uses the MQTT_BROKER environment variable as connect URI" do
      ENV['MQTT_BROKER'] = 'mqtt://mqtt.example.com:1234'
      client = MQTT::Client.new
      client.remote_host.should == 'mqtt.example.com'
      client.remote_port.should == 1234
    end

    it "with an unsupported URI scheme" do
      lambda {
        client = MQTT::Client.new(URI.parse('http://mqtt.example.com/'))
      }.should raise_error(
        'Only the mqtt:// and mqtts:// schemes are supported'
      )
    end

    it "with three arguments" do
      lambda {
        client = MQTT::Client.new(1, 2, 3)
      }.should raise_error(
        'Unsupported number of arguments'
      )
    end
  end

  describe "setting a client certificate file path" do
    it "should add a certificate to the SSL context" do
      client.ssl_context.cert.should be_nil
      client.cert_file = fixture_path('client.pem')
      client.ssl_context.cert.should be_a(OpenSSL::X509::Certificate)
    end
  end

  describe "setting a client private key file path" do
    it "should add a certificate to the SSL context" do
      client.ssl_context.key.should be_nil
      client.key_file = fixture_path('client.key')
      client.ssl_context.key.should be_a(OpenSSL::PKey::RSA)
    end
  end

  describe "setting a Certificate Authority file path" do
    it "should add a CA file path to the SSL context" do
      client.ssl_context.ca_file.should be_nil
      client.ca_file = fixture_path('root-ca.pem')
      client.ssl_context.ca_file.should == fixture_path('root-ca.pem')
    end

    it "should enable peer verification" do
      client.ca_file = fixture_path('root-ca.pem')
      client.ssl_context.verify_mode.should == OpenSSL::SSL::VERIFY_PEER
    end
  end

  describe "when calling the 'connect' method on a client" do
    before(:each) do
      TCPSocket.stub(:new).and_return(socket)
      Thread.stub(:new)
      client.stub(:receive_connack)
    end

    it "should create a TCP Socket if not connected" do
      TCPSocket.should_receive(:new).once.and_return(socket)
      client.connect('myclient')
    end

    it "should not create a new TCP Socket if connected" do
      client.stub(:connected?).and_return(true)
      TCPSocket.should_receive(:new).never
      client.connect('myclient')
    end

    it "should start the reader thread if not connected" do
      Thread.should_receive(:new).once
      client.connect('myclient')
    end

    it "should write a valid CONNECT packet to the socket if not connected" do
      client.connect('myclient')
      socket.string.should == "\020\026\x00\x06MQIsdp\x03\x02\x00\x0f\x00\x08myclient"
    end

    it "should try and read an acknowledgement packet to the socket if not connected" do
      client.should_receive(:receive_connack).once
      client.connect('myclient')
    end

    it "should throw an exception if no host is configured" do
      lambda {
        client = MQTT::Client.new
        client.connect
      }.should raise_error(
        'No MQTT broker host set when attempting to connect'
      )
    end

    it "should disconnect after connecting, if a block is given" do
      client.should_receive(:disconnect).once
      client.connect('myclient') { nil }
    end

    it "should not disconnect after connecting, if no block is given" do
      client.should_receive(:disconnect).never
      client.connect('myclient')
    end

    it "should include the username and password for an authenticated connection" do
      client.username = 'username'
      client.password = 'password'
      client.connect('myclient')
      socket.string.should ==
        "\x10\x2A"+
        "\x00\x06MQIsdp"+
        "\x03\xC2\x00\x0f"+
        "\x00\x08myclient"+
        "\x00\x08username"+
        "\x00\x08password"
    end

    context "no client id is given" do
      it "should throw an exception if the clean session flag is false" do
        lambda {
          client.client_id = nil
          client.clean_session = false
          client.connect
        }.should raise_error(
          'Must provide a client_id if clean_session is set to false'
        )
      end

      it "should generate a client if the clean session flag is true" do
        client.client_id = nil
        client.clean_session = true
        client.connect
        client.client_id.should match(/^\w+$/)
      end
    end

    context "and using ssl" do
      let(:ssl_socket) {
        double(
          "SSLSocket",
          :sync_close= => true,
          :write => true,
          :connect => true,
          :closed? => false
        )
      }

      it "should use ssl if it enabled using the :ssl => true parameter" do
        OpenSSL::SSL::SSLSocket.should_receive(:new).and_return(ssl_socket)
        ssl_socket.should_receive(:connect)

        client = MQTT::Client.new('mqtt.example.com', :ssl => true)
        client.stub(:receive_connack)
        client.connect
      end

      it "should use ssl if it enabled using the mqtts:// scheme" do
        OpenSSL::SSL::SSLSocket.should_receive(:new).and_return(ssl_socket)
        ssl_socket.should_receive(:connect)

        client = MQTT::Client.new('mqtts://mqtt.example.com')
        client.stub(:receive_connack)
        client.connect
      end

      it "should use set the SSL version, if the :ssl parameter is a symbol" do
        OpenSSL::SSL::SSLSocket.should_receive(:new).and_return(ssl_socket)
        ssl_socket.should_receive(:connect)

        client = MQTT::Client.new('mqtt.example.com', :ssl => :TLSv1)
        client.ssl_context.should_receive('ssl_version=').with(:TLSv1)
        client.stub(:receive_connack)
        client.connect
      end
    end

    context "with a last will and testament set" do
      before(:each) do
        client.set_will('topic', 'hello', retain=false, qos=1)
      end

      it "should have set the Will's topic" do
        client.will_topic.should == 'topic'
      end

      it "should have set the Will's payload" do
        client.will_payload.should == 'hello'
      end

      it "should have set the Will's retain flag to true" do
        client.will_retain.should be_false
      end

      it "should have set the Will's retain QOS value to 1" do
        client.will_qos.should == 1
      end

      it "should include the will in the CONNECT message" do
        client.connect('myclient')
        socket.string.should ==
          "\x10\x24"+
          "\x00\x06MQIsdp"+
          "\x03\x0e\x00\x0f"+
          "\x00\x08myclient"+
          "\x00\x05topic\x00\x05hello"
      end
    end

  end

  describe "calling 'connect' on the class" do
    it "should create a new client object" do
      client = double("MQTT::Client")
      allow(client).to receive(:connect)
      expect(MQTT::Client).to receive(:new).once.and_return(client)
      MQTT::Client.connect
    end

    it "should call connect new client object" do
      client = double("MQTT::Client")
      expect(client).to receive(:connect)
      allow(MQTT::Client).to receive(:new).once.and_return(client)
      MQTT::Client.connect
    end

    it "should return the new client object" do
      client = double("MQTT::Client")
      allow(client).to receive(:connect)
      allow(MQTT::Client).to receive(:new).once.and_return(client)
      MQTT::Client.connect.should == client
    end
  end

  describe "when calling the 'receive_connack' method" do
    before(:each) do
      client.instance_variable_set('@socket', socket)
      IO.stub(:select).and_return([[socket], [], []])
    end

    it "should not throw an exception for a successful CONNACK packet" do
      socket.write("\x20\x02\x00\x00")
      socket.rewind
      lambda { client.send(:receive_connack) }.should_not raise_error
    end

    it "should throw an exception if the packet type isn't CONNACK" do
      socket.write("\xD0\x00")
      socket.rewind
      lambda { client.send(:receive_connack) }.should raise_error(MQTT::ProtocolException)
    end

    it "should throw an exception if the CONNACK packet return code is 'unacceptable protocol version'" do
      socket.write("\x20\x02\x00\x01")
      socket.rewind
      lambda { client.send(:receive_connack) }.should raise_error(MQTT::ProtocolException, /unacceptable protocol version/i)
    end

    it "should throw an exception if the CONNACK packet return code is 'client identifier rejected'" do
      socket.write("\x20\x02\x00\x02")
      socket.rewind
      lambda { client.send(:receive_connack) }.should raise_error(MQTT::ProtocolException, /client identifier rejected/i)
    end

    it "should throw an exception if the CONNACK packet return code is 'broker unavailable'" do
      socket.write("\x20\x02\x00\x03")
      socket.rewind
      lambda { client.send(:receive_connack) }.should raise_error(MQTT::ProtocolException, /broker unavailable/i)
    end

    it "should throw an exception if the CONNACK packet return code is an unknown" do
      socket.write("\x20\x02\x00\xAA")
      socket.rewind
      lambda { client.send(:receive_connack) }.should raise_error(MQTT::ProtocolException, /connection refused/i)
    end
  end

  describe "when calling the 'disconnect' method" do
    before(:each) do
      thread = double('Read Thread', :alive? => true, :kill => true)
      client.instance_variable_set('@socket', socket)
      client.instance_variable_set('@read_thread', thread)
    end

    it "should not do anything if the socket is already disconnected" do
      client.stub(:connected?).and_return(false)
      client.disconnect(true)
      socket.string.should == ""
    end

    it "should write a valid DISCONNECT packet to the socket if connected and the send_msg=true an" do
      client.stub(:connected?).and_return(true)
      client.disconnect(true)
      socket.string.should == "\xE0\x00"
    end

    it "should not write anything to the socket if the send_msg=false" do
      client.stub(:connected?).and_return(true)
      client.disconnect(false)
      socket.string.should be_empty
    end

    it "should call the close method on the socket" do
      socket.should_receive(:close)
      client.disconnect
    end
  end

  describe "when calling the 'ping' method" do
    before(:each) do
      client.instance_variable_set('@socket', socket)
    end

    it "should write a valid PINGREQ packet to the socket" do
      client.ping
      socket.string.should == "\xC0\x00"
    end

    it "should update the time a ping was last sent" do
      client.instance_variable_set('@last_pingreq', 0)
      client.ping
      client.instance_variable_get('@last_pingreq').should_not == 0
    end
  end

  describe "when calling the 'publish' method" do
    before(:each) do
      client.instance_variable_set('@socket', socket)
    end

    it "should write a valid PUBLISH packet to the socket without the retain flag" do
      client.publish('topic','payload', false, 0)
      socket.string.should == "\x30\x0e\x00\x05topicpayload"
    end

    it "should write a valid PUBLISH packet to the socket with the retain flag set" do
      client.publish('topic','payload', true, 0)
      socket.string.should == "\x31\x0e\x00\x05topicpayload"
    end

    it "should write a valid PUBLISH packet to the socket with the QOS set to 1" do
      client.publish('topic','payload', false, 1)
      socket.string.should == "\x32\x10\x00\x05topic\x00\x01payload"
    end

    it "should write a valid PUBLISH packet to the socket with the QOS set to 2" do
      client.publish('topic','payload', false, 2)
      socket.string.should == "\x34\x10\x00\x05topic\x00\x01payload"
    end
  end

  describe "when calling the 'subscribe' method" do
    before(:each) do
      client.instance_variable_set('@socket', socket)
    end

    it "should write a valid SUBSCRIBE packet to the socket if given a single topic String" do
      client.subscribe('a/b')
      socket.string.should == "\x82\x08\x00\x01\x00\x03a/b\x00"
    end

    it "should write a valid SUBSCRIBE packet to the socket if given a two topic Strings in an Array" do
      client.subscribe('a/b','c/d')
      socket.string.should == "\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x00"
    end

    it "should write a valid SUBSCRIBE packet to the socket if given a two topic Strings with QoS in an Array" do
      client.subscribe(['a/b',0],['c/d',1])
      socket.string.should == "\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x01"
    end

    it "should write a valid SUBSCRIBE packet to the socket if given a two topic Strings with QoS in a Hash" do
      client.subscribe('a/b' => 0,'c/d' => 1)
      socket.string.should == "\x82\x0e\x00\x01\x00\x03a/b\x00\x00\x03c/d\x01"
    end
  end

  describe "when calling the 'queue_length' method" do
    it "should return 0 if there are no incoming messages waiting" do
      client.queue_length.should == 0
    end

    it "should return 1 if there is one incoming message waiting" do
      inject_packet(:topic => 'topic0', :payload => 'payload0', :qos => 0)
      client.queue_length.should == 1
    end

    it "should return 2 if there are two incoming message waiting" do
      inject_packet(:topic => 'topic0', :payload => 'payload0', :qos => 0)
      inject_packet(:topic => 'topic0', :payload => 'payload1', :qos => 0)
      client.queue_length.should == 2
    end
  end

  describe "when calling the 'queue_emtpy?' method" do
    it "should return return true if there no incoming messages waiting" do
      client.queue_empty?.should be_true
    end

    it "should return return false if there is an incoming messages waiting" do
      inject_packet(:topic => 'topic0', :payload => 'payload0', :qos => 0)
      client.queue_empty?.should be_false
    end
  end

  describe "when calling the 'get' method" do
    before(:each) do
      client.instance_variable_set('@socket', socket)
    end

    it "should successfull receive a valid PUBLISH packet with a QoS 0" do
      inject_packet(:topic => 'topic0', :payload => 'payload0', :qos => 0)
      topic,payload = client.get
      topic.should == 'topic0'
      payload.should == 'payload0'
    end

    it "should successfull receive a valid PUBLISH packet with a QoS 1" do
      inject_packet(:topic => 'topic1', :payload => 'payload1', :qos => 1)
      topic,payload = client.get
      topic.should == 'topic1'
      payload.should == 'payload1'
      client.queue_empty?.should be_true
    end

    context "with a block" do
      it "should successfull receive a more than 1 message" do
        inject_packet(:topic => 'topic0', :payload => 'payload0')
        inject_packet(:topic => 'topic1', :payload => 'payload1')
        payloads = []
        client.get do |topic,payload|
          payloads << payload
          break if payloads.size > 1
        end
        payloads.size.should == 2
        payloads.should == ['payload0', 'payload1']
      end
    end
  end

  describe "when calling the 'get_packet' method" do
    before(:each) do
      client.instance_variable_set('@socket', socket)
    end

    it "should successfull receive a valid PUBLISH packet with a QoS 0" do
      inject_packet(:topic => 'topic0', :payload => 'payload0', :qos => 0)
      packet = client.get_packet
      packet.class.should == MQTT::Packet::Publish
      packet.qos.should == 0
      packet.topic.should == 'topic0'
      packet.payload.should == 'payload0'
    end

    it "should successfull receive a valid PUBLISH packet with a QoS 1" do
      inject_packet(:topic => 'topic1', :payload => 'payload1', :qos => 1)
      packet = client.get_packet
      packet.class.should == MQTT::Packet::Publish
      packet.qos.should == 1
      packet.topic.should == 'topic1'
      packet.payload.should == 'payload1'
      client.queue_empty?.should be_true
    end

    context "with a block" do
      it "should successfull receive a more than 1 packet" do
        inject_packet(:topic => 'topic0', :payload => 'payload0')
        inject_packet(:topic => 'topic1', :payload => 'payload1')
        packets = []
        client.get_packet do |packet|
          packets << packet
          break if packets.size > 1
        end
        packets.size.should == 2
        packets.map{|p| p.payload}.should == ['payload0', 'payload1']
      end
    end
  end

  describe "when calling the 'unsubscribe' method" do
    before(:each) do
      client.instance_variable_set('@socket', socket)
    end

    it "should write a valid UNSUBSCRIBE packet to the socket if given a single topic String" do
      client.unsubscribe('a/b')
      socket.string.should == "\xa2\x07\x00\x01\x00\x03a/b"
    end

    it "should write a valid UNSUBSCRIBE packet to the socket if given a two topic Strings" do
      client.unsubscribe('a/b','c/d')
      socket.string.should == "\xa2\x0c\x00\x01\x00\x03a/b\x00\x03c/d"
    end

    it "should write a valid UNSUBSCRIBE packet to the socket if given an array of Strings" do
      client.unsubscribe(['a/b','c/d'])
      socket.string.should == "\xa2\x0c\x00\x01\x00\x03a/b\x00\x03c/d"
    end
  end

  describe "when calling the 'receive_packet' method" do
    before(:each) do
      client.instance_variable_set('@socket', socket)
      IO.stub(:select).and_return([[socket], [], []])
      @read_queue = client.instance_variable_get('@read_queue')
      @parent_thread = Thread.current[:parent] = double('Parent Thread')
      @parent_thread.stub(:raise)
    end

    it "should put PUBLISH messages on to the read queue" do
      socket.write("\x30\x0e\x00\x05topicpayload")
      socket.rewind
      client.send(:receive_packet)
      @read_queue.size.should == 1
    end

    it "should not put other messages on to the read queue" do
      socket.write("\x20\x02\x00\x00")
      socket.rewind
      client.send(:receive_packet)
      @read_queue.size.should == 0
    end

    it "should send a ping packet if one is due" do
      IO.should_receive(:select).and_return(nil)
      client.instance_variable_set('@last_pingreq', Time.at(0))
      client.should_receive(:ping).once
      client.send(:receive_packet)
    end

    it "should close the socket if there is an exception" do
      socket.should_receive(:close).once
      MQTT::Packet.stub(:read).and_raise(MQTT::Exception)
      client.send(:receive_packet)
    end

    it "should pass exceptions up to parent thread" do
      @parent_thread.should_receive(:raise).once
      MQTT::Packet.stub(:read).and_raise(MQTT::Exception)
      client.send(:receive_packet)
    end
  end

  describe "generating a client identifier" do
    context "with default parameters" do
      let(:client_id) { MQTT::Client.generate_client_id }

      it "should be less or equal to 23 characters long" do
        client_id.length.should <= 23
      end

      it "should have a prefix of ruby_" do
        client_id.should match(/^ruby_/)
      end

      it "should end in 16 characters of lowercase letters and numbers" do
        client_id.should match(/_[a-z0-9]{16}$/)
      end
    end

    context "with an alternative prefix" do
      let(:client_id) { MQTT::Client.generate_client_id('test_') }

      it "should be less or equal to 23 characters long" do
        client_id.length.should <= 23
      end

      it "should have a prefix of test_" do
        client_id.should match(/^test_/)
      end

      it "should end in 16 characters of lowercase letters and numbers" do
        client_id.should match(/_[a-z0-9]{16}$/)
      end
    end
  end

  private

  def inject_packet(opts={})
    packet = MQTT::Packet::Publish.new(opts)
    client.instance_variable_get('@read_queue').push(packet)
  end

end
