# encoding: BINARY
# Encoding is set to binary, so that the binary packets aren't validated as UTF-8

$:.unshift(File.dirname(__FILE__))

require 'spec_helper'
require 'mqtt'

describe MQTT::Packet do

  describe "when creating a new packet" do
    it "should allow you to set the packet dup flag as a hash parameter" do
      packet = MQTT::Packet.new( :duplicate => true )
      packet.duplicate.should be_true
    end

    it "should allow you to set the packet QOS level as a hash parameter" do
      packet = MQTT::Packet.new( :qos => 2 )
      packet.qos.should == 2
    end

    it "should allow you to set the packet retain flag as a hash parameter" do
      packet = MQTT::Packet.new( :retain => true )
      packet.retain.should be_true
    end

    it "should have a custom inspect method" do
      packet = MQTT::Packet.new
      packet.inspect.should == '#<MQTT::Packet>'
    end

    it "should throw an exception the QoS is greater than 2" do
      lambda {
        packet = MQTT::Packet.new( :qos => 3 )
      }.should raise_error(
        'Invalid QoS value: 3'
      )
    end

    it "should throw an exception the QoS is less than 0" do
      lambda {
        packet = MQTT::Packet.new( :qos => -1 )
      }.should raise_error(
        'Invalid QoS value: -1'
      )
    end
  end

  describe "when setting packet parameters" do
    let(:packet) {
      MQTT::Packet.new(
        :duplicate => false,
        :qos => 0,
        :retain => false
      )
    }

    it "should have a type_id method to get the integer ID of the packet type" do
      packet = MQTT::Packet::Pingreq.new
      packet.type_id.should == 12
    end

    it "should let you change the dup flag of a packet" do
      packet.duplicate = true
      packet.duplicate.should be_true
    end

    it "should let you change the dup flag of a packet using an integer" do
      packet.duplicate = 1
      packet.duplicate.should be_true
    end

    it "should let you change the retain flag of a packet" do
      packet.retain = true
      packet.retain.should be_true
    end

    it "should let you change the retain flag of a packet using an integer" do
      packet.retain = 1
      packet.retain.should be_true
    end
  end

  it "should let you attributes using the update_attributes method" do
    packet = MQTT::Packet.new(:qos => 1)
    packet.update_attributes(:qos => 2)
    packet.qos.should == 2
  end

  describe "protected methods" do
    let(:packet) { MQTT::Packet.new }

    it "should provide a encode_bytes method to get some bytes as Integers" do
      data = packet.send(:encode_bytes, 0x48, 0x65, 0x6c, 0x6c, 'o'.unpack('C1')[0])
      data.should == 'Hello'
    end

    it "should provide a add_short method to get a big-endian unsigned 16-bit integer" do
      data = packet.send(:encode_short, 1024)
      data.should == "\x04\x00"
      data.encoding.to_s.should == "ASCII-8BIT"
    end

    it "should provide a add_string method to get a string preceeded by its length" do
      data = packet.send(:encode_string, 'quack')
      data.should == "\x00\x05quack"
      data.encoding.to_s.should == "ASCII-8BIT"
    end

    it "should provide a shift_short method to get a 16-bit unsigned integer" do
      buffer = "\x22\x8Bblahblah"
      packet.send(:shift_short,buffer).should == 8843
      buffer.should == 'blahblah'
    end

    it "should provide a shift_byte method to get one byte as integers" do
      buffer = "\x01blahblah"
      packet.send(:shift_byte,buffer).should == 1
      buffer.should == 'blahblah'
    end

    it "should provide a shift_string method to get a string preceeded by its length" do
      buffer = "\x00\x05Hello World"
      packet.send(:shift_string,buffer).should == "Hello"
      buffer.should == ' World'
    end
  end
end

describe MQTT::Packet::Publish do
  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with default QOS and no flags" do
      packet = MQTT::Packet::Publish.new( :topic => 'test', :payload => 'hello world' )
      packet.to_s.should == "\x30\x11\x00\x04testhello world"
    end

    it "should output the correct bytes for a packet with QOS 1 and no flags" do
      packet = MQTT::Packet::Publish.new( :qos => 1, :message_id => 5, :topic => 'a/b', :payload => 'hello world' )
      packet.to_s.should == "\x32\x12\x00\x03a/b\x00\x05hello world"
    end

    it "should output the correct bytes for a packet with QOS 2 and retain flag set" do
      packet = MQTT::Packet::Publish.new( :qos => 2, :retain => true, :message_id => 5, :topic => 'c/d', :payload => 'hello world' )
      packet.to_s.should == "\x35\x12\x00\x03c/d\x00\x05hello world"
    end

    it "should output the correct bytes for a packet with QOS 2 and dup flag set" do
      packet = MQTT::Packet::Publish.new( :qos => 2, :duplicate => true, :message_id => 5, :topic => 'c/d', :payload => 'hello world' )
      packet.to_s.should == "\x3C\x12\x00\x03c/d\x00\x05hello world"
    end

    it "should output a string as binary / 8-bit ASCII" do
      packet = MQTT::Packet::Publish.new( :topic => 'test', :payload => 'hello world' )
      packet.to_s.encoding.to_s.should == "ASCII-8BIT"
    end

    it "should support passing in non-strings to the topic and payload" do
      packet = MQTT::Packet::Publish.new( :topic => :symbol, :payload => 1234 )
      packet.to_s.should == "\x30\x0c\x00\x06symbol1234"
    end

    it "should throw an exception when there is no topic name" do
      lambda {
        MQTT::Packet::Publish.new.to_s
      }.should raise_error(
        'Invalid topic name when serialising packet'
      )
    end

    it "should throw an exception when there is an empty topic name" do
      lambda {
        MQTT::Packet::Publish.new( :topic => '' ).to_s
      }.should raise_error(
        'Invalid topic name when serialising packet'
      )
    end
  end

  describe "when serialising an oversized packet" do
    it "should throw an exception when body is bigger than 256MB" do
      lambda {
        packet = MQTT::Packet::Publish.new( :topic => 'test', :payload => 'x'*268435455 )
        packet.to_s
      }.should raise_error(
        'Error serialising packet: body is more than 256MB'
      )
    end
  end

  describe "when parsing a packet with QOS 0" do
    let(:packet) { MQTT::Packet.parse( "\x30\x11\x00\x04testhello world" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Publish
    end

    it "should set the QOS level correctly" do
      packet.qos.should == 0
    end

    it "should set the RETAIN flag correctly" do
      packet.retain.should be_false
    end

    it "should set the DUP flag correctly" do
      packet.duplicate.should be_false
    end

    it "should set the topic name correctly" do
      packet.topic.should == 'test'
      packet.topic.encoding.to_s.should == 'UTF-8'
    end

    it "should set the payload correctly" do
      packet.payload.should == 'hello world'
      packet.payload.encoding.to_s.should == 'ASCII-8BIT'
    end
  end

  describe "when parsing a packet with QOS 2 and retain and dup flags set" do
    let(:packet) { MQTT::Packet.parse( "\x3D\x12\x00\x03c/d\x00\x05hello world" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Publish
    end

    it "should set the QOS level correctly" do
      packet.qos.should == 2
    end

    it "should set the RETAIN flag correctly" do
      packet.retain.should be_true
    end

    it "should set the DUP flag correctly" do
      packet.duplicate.should be_true
    end

    it "should set the topic name correctly" do
      packet.topic.should == 'c/d'
      packet.topic.encoding.to_s.should == 'UTF-8'
    end

    it "should set the payload correctly" do
      packet.payload.should == 'hello world'
      packet.payload.encoding.to_s.should == 'ASCII-8BIT'
    end
  end

  describe "when parsing a packet with a invalid QoS value" do
    it "should throw an exception" do
      lambda {
        packet = MQTT::Packet.parse( "\x36\x12\x00\x03a/b\x00\x05hello world" )
      }.should raise_error(
        'Invalid QoS value: 3'
      )
    end
  end

  describe "when parsing a packet with a body of 314 bytes" do
    let(:packet) {
      # 0x30 = publish
      # 0xC1 = (65 * 1)
      # 0x02 = (2 * 128)
      MQTT::Packet.parse( "\x30\xC1\x02\x00\x05topic" + ('x' * 314) )
    }

    it "should parse the packet type correctly" do
      packet.class.should == MQTT::Packet::Publish
    end

    it "should get the topic name correctly" do
      packet.topic.should == 'topic'
    end

    it "should get the body length correctly" do
      packet.payload.bytesize.should == 314
    end
  end

  describe "when parsing a packet with a body of 16kbytes" do
    let(:packet) do
      # 0x30 = publish
      # 0x87 = (7 * 1)
      # 0x80 = (0 * 128)
      # 0x01 = (1 * 16384)
      MQTT::Packet.parse( "\x30\x87\x80\x01\x00\x05topic" + ('x'*16384) )
    end

    it "should parse the packet type correctly" do
      packet.class.should == MQTT::Packet::Publish
    end

    it "should get the topic name correctly" do
      packet.topic.should == 'topic'
    end

    it "should get the body length correctly" do
      packet.payload.bytesize.should == 16384
    end
  end

  describe "processing a packet containing UTF-8 character" do
    let(:packet) do
      MQTT::Packet::Publish.new(
        :topic => "Test ①".force_encoding("UTF-8"),
        :payload => "Snowman: ☃".force_encoding("UTF-8")
      )
    end

    it "should have the correct topic byte length" do
      packet.topic.bytesize.should == 8
    end

    it "should have the correct topic string length", :unless => RUBY_VERSION =~ /^1\.8/ do
      # Ruby 1.8 doesn't support UTF-8 properly
      packet.topic.length.should == 6
    end

    it "should have the correct payload byte length" do
      packet.payload.bytesize.should == 12
    end

    it "should have the correct payload string length", :unless => RUBY_VERSION =~ /^1\.8/ do
      # Ruby 1.8 doesn't support UTF-8 properly
      packet.payload.length.should == 10
    end

    it "should encode to MQTT packet correctly" do
      packet.to_s.should == "\x30\x16\x00\x08Test \xE2\x91\xA0Snowman: \xE2\x98\x83".force_encoding('BINARY')
    end

    it "should parse the serialised packet" do
      packet2 = MQTT::Packet.parse( packet.to_s )
      packet2.topic.should == "Test ①".force_encoding('UTF-8')
      packet2.payload.should == "Snowman: ☃".force_encoding('BINARY')
    end
  end

  describe "reading a packet from a socket" do
    let(:socket) { StringIO.new("\x30\x11\x00\x04testhello world") }
    let(:packet) { MQTT::Packet.read(socket) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Publish
    end

    it "should set the body length is read correctly" do
      packet.body_length.should == 17
    end

    it "should set the QOS level correctly" do
      packet.qos.should == 0
    end

    it "should set the RETAIN flag correctly" do
      packet.retain.should be_false
    end

    it "should set the DUP flag correctly" do
      packet.duplicate.should be_false
    end

    it "should set the topic name correctly" do
      packet.topic.should == 'test'
      packet.topic.encoding.to_s.should == 'UTF-8'
    end

    it "should set the payload correctly" do
      packet.payload.should == 'hello world'
      packet.payload.encoding.to_s.should == 'ASCII-8BIT'
    end
  end

  describe "when calling the inspect method" do
    it "should output the payload, if it is less than 16 bytes" do
      packet = MQTT::Packet::Publish.new( :topic => "topic", :payload => "payload" )
      packet.inspect.should == "#<MQTT::Packet::Publish: d0, q0, r0, m0, 'topic', 'payload'>"
    end

    it "should output the length of the payload, if it is more than 16 bytes" do
      packet = MQTT::Packet::Publish.new( :topic => "topic", :payload => 'x'*32 )
      packet.inspect.should == "#<MQTT::Packet::Publish: d0, q0, r0, m0, 'topic', ... (32 bytes)>"
    end

    it "should only output the length of a binary payload" do
      packet = MQTT::Packet.parse("\x31\x12\x00\x04test\x8D\xF8\x09\x40\xC4\xE7\x4f\xF0\xFF\x30\xE0\xE7")
      packet.inspect.should == "#<MQTT::Packet::Publish: d0, q0, r1, m0, 'test', ... (12 bytes)>"
    end
  end
end

describe MQTT::Packet::Connect do
  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with no flags" do
      packet = MQTT::Packet::Connect.new( :client_id => 'myclient' )
      packet.to_s.should == "\020\026\x00\x06MQIsdp\x03\x02\x00\x0f\x00\x08myclient"
    end

    it "should output the correct bytes for a packet with clean session turned off" do
      packet = MQTT::Packet::Connect.new(
        :client_id => 'myclient',
        :clean_session => false
      )
      packet.to_s.should == "\020\026\x00\x06MQIsdp\x03\x00\x00\x0f\x00\x08myclient"
    end

    it "should throw an exception when there is no client identifier" do
      lambda {
        MQTT::Packet::Connect.new.to_s
      }.should raise_error(
        'Invalid client identifier when serialising packet'
      )
    end

    it "should throw an exception if the keep alive value is less than 0" do
      lambda {
        MQTT::Packet::Connect.new(:client_id => 'test', :keep_alive => -2).to_s
      }.should raise_error(
        'Invalid keep-alive value: cannot be less than 0'
      )
    end

    it "should output the correct bytes for a packet with a Will" do
      packet = MQTT::Packet::Connect.new(
        :client_id => 'myclient',
        :clean_session => true,
        :will_qos => 1,
        :will_retain => false,
        :will_topic => 'topic',
        :will_payload => 'hello'
      )
      packet.to_s.should ==
        "\x10\x24"+
        "\x00\x06MQIsdp"+
        "\x03\x0e\x00\x0f"+
        "\x00\x08myclient"+
        "\x00\x05topic\x00\x05hello"
    end

    it "should output the correct bytes for a packet with a username and password" do
      packet = MQTT::Packet::Connect.new(
        :client_id => 'myclient',
        :username => 'username',
        :password => 'password'
      )
      packet.to_s.should ==
        "\x10\x2A"+
        "\x00\x06MQIsdp"+
        "\x03\xC2\x00\x0f"+
        "\x00\x08myclient"+
        "\x00\x08username"+
        "\x00\x08password"
    end

    it "should output the correct bytes for a packet with everything" do
      packet = MQTT::Packet::Connect.new(
        :client_id => '12345678901234567890123',
        :clean_session => true,
        :keep_alive => 65535,
        :will_qos => 2,
        :will_retain => true,
        :will_topic => 'will_topic',
        :will_payload => 'will_message',
        :username => 'user0123456789',
        :password => 'pass0123456789'
      )
      packet.to_s.should ==
        "\x10\x5F"+ # fixed header (2)
        "\x00\x06MQIsdp"+ # protocol name (8)
        "\x03\xf6"+ # protocol version + flags (2)
        "\xff\xff"+ # keep alive (2)
        "\x00\x1712345678901234567890123"+ # client identifier (25)
        "\x00\x0Awill_topic"+ # will topic (12)
        "\x00\x0Cwill_message"+ # will message (14)
        "\x00\x0Euser0123456789"+ # username (16)
        "\x00\x0Epass0123456789"  # password (16)
    end

  end

  describe "when parsing a simple Connect packet" do
    let(:packet) do
      MQTT::Packet.parse(
        "\x10\x16\x00\x06MQIsdp\x03\x00\x00\x0a\x00\x08myclient"
      )
    end

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Connect
    end

    it "should set the QOS of the packet correctly" do
      packet.qos.should == 0
    end

    it "should set the Protocol Name of the packet correctly" do
      packet.protocol_name.should == 'MQIsdp'
      packet.protocol_name.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Protocol Version of the packet correctly" do
      packet.protocol_version.should == 3
    end

    it "should set the Client Identifier of the packet correctly" do
      packet.client_id.should == 'myclient'
      packet.client_id.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Keep Alive timer of the packet correctly" do
      packet.keep_alive.should == 10
    end

    it "should set not have the clean session flag set" do
      packet.clean_session.should be_false
    end

    it "should set the the username field of the packet to nil" do
      packet.username.should be_nil
    end

    it "should set the the password field of the packet to nil" do
      packet.password.should be_nil
    end
  end

  describe "when parsing a Connect packet with the clean session flag set" do
    let(:packet) do
      MQTT::Packet.parse(
        "\x10\x16\x00\x06MQIsdp\x03\x02\x00\x0a\x00\x08myclient"
      )
    end

    it "should set the clean session flag" do
      packet.clean_session.should be_true
    end
  end

  describe "when parsing a Connect packet with a Will and Testament" do
    let(:packet) do
      MQTT::Packet.parse(
        "\x10\x24\x00\x06MQIsdp\x03\x0e\x00\x0a\x00\x08myclient\x00\x05topic\x00\x05hello"
      )
    end

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Connect
    end

    it "should set the QOS of the packet correctly" do
      packet.qos.should == 0
    end

    it "should set the Protocol Name of the packet correctly" do
      packet.protocol_name.should == 'MQIsdp'
      packet.protocol_name.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Protocol Version of the packet correctly" do
      packet.protocol_version.should == 3
    end

    it "should set the Client Identifier of the packet correctly" do
      packet.client_id.should == 'myclient'
      packet.client_id.encoding.to_s.should == 'UTF-8'
    end

    it "should set the clean session flag should be set" do
      packet.clean_session.should be_true
    end

    it "should set the QOS of the Will should be 1" do
      packet.will_qos.should == 1
    end

    it "should set the Will retain flag should be false" do
      packet.will_retain.should be_false
    end

    it "should set the Will topic of the packet correctly" do
      packet.will_topic.should == 'topic'
      packet.will_topic.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Will payload of the packet correctly" do
      packet.will_payload.should == 'hello'
      packet.will_payload.encoding.to_s.should == 'UTF-8'
    end
  end

  describe "when parsing a Connect packet with a username and password" do
    let(:packet) do
      MQTT::Packet.parse(
        "\x10\x2A"+
        "\x00\x06MQIsdp"+
        "\x03\xC0\x00\x0a"+
        "\x00\x08myclient"+
        "\x00\x08username"+
        "\x00\x08password"
      )
    end

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Connect
    end

    it "should set the QOS of the packet correctly" do
      packet.qos.should == 0
    end

    it "should set the Protocol Name of the packet correctly" do
      packet.protocol_name.should == 'MQIsdp'
      packet.protocol_name.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Protocol Version of the packet correctly" do
      packet.protocol_version.should == 3
    end

    it "should set the Client Identifier of the packet correctly" do
      packet.client_id.should == 'myclient'
      packet.client_id.encoding.to_s.should == 'UTF-8'
   end

    it "should set the Keep Alive Timer of the packet correctly" do
      packet.keep_alive.should == 10
    end

    it "should set the Username of the packet correctly" do
      packet.username.should == 'username'
      packet.username.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Username of the packet correctly" do
      packet.password.should == 'password'
      packet.password.encoding.to_s.should == 'UTF-8'
    end
  end

  describe "when parsing a Connect that has a username but no password" do
    let(:packet) do
      MQTT::Packet.parse(
        "\x10\x20\x00\x06MQIsdp\x03\x80\x00\x0a\x00\x08myclient\x00\x08username"
      )
    end

    it "should set the Username of the packet correctly" do
      packet.username.should == 'username'
      packet.username.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Username of the packet correctly" do
      packet.password.should be_nil
    end
  end

  describe "when parsing a Connect that has a password but no username" do
    let(:packet) do
      MQTT::Packet.parse(
        "\x10\x20\x00\x06MQIsdp\x03\x40\x00\x0a\x00\x08myclient\x00\x08password"
      )
    end

    it "should set the Username of the packet correctly" do
      packet.username.should be_nil
    end

    it "should set the Username of the packet correctly" do
      packet.password.should == 'password'
      packet.password.encoding.to_s.should == 'UTF-8'
    end
  end

  describe "when parsing a Connect packet has the username and password flags set but doesn't have the fields" do
    let(:packet) do
      MQTT::Packet.parse(
        "\x10\x16\x00\x06MQIsdp\x03\xC0\x00\x0a\x00\x08myclient"
      )
    end

    it "should set the Username of the packet correctly" do
      packet.username.should be_nil
    end

    it "should set the Username of the packet correctly" do
      packet.password.should be_nil
    end
  end

  describe "when parsing a Connect packet with every option set" do
    let(:packet) do
      MQTT::Packet.parse(
        "\x10\x5F"+ # fixed header (2)
        "\x00\x06MQIsdp"+ # protocol name (8)
        "\x03\xf6"+ # protocol version + flags (2)
        "\xff\xff"+ # keep alive (2)
        "\x00\x1712345678901234567890123"+ # client identifier (25)
        "\x00\x0Awill_topic"+ # will topic (12)
        "\x00\x0Cwill_message"+ # will message (14)
        "\x00\x0Euser0123456789"+ # username (16)
        "\x00\x0Epass0123456789"  # password (16)
      )
    end

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Connect
    end

    it "should set the QOS of the packet correctly" do
      packet.qos.should == 0
    end

    it "should set the Protocol Name of the packet correctly" do
      packet.protocol_name.should == 'MQIsdp'
      packet.protocol_name.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Protocol Version of the packet correctly" do
      packet.protocol_version.should == 3
    end

    it "should set the Keep Alive Timer of the packet correctly" do
      packet.keep_alive.should == 65535
    end

    it "should set the Client Identifier of the packet correctly" do
      packet.client_id.should == '12345678901234567890123'
      packet.client_id.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Will QoS of the packet correctly" do
      packet.will_qos.should == 2
    end

    it "should set the Will retain flag of the packet correctly" do
      packet.will_retain.should be_true
    end

    it "should set the Will topic of the packet correctly" do
      packet.will_topic.should == 'will_topic'
      packet.will_topic.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Will payload of the packet correctly" do
      packet.will_payload.should == 'will_message'
      packet.will_payload.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Username of the packet correctly" do
      packet.username.should == 'user0123456789'
      packet.username.encoding.to_s.should == 'UTF-8'
    end

    it "should set the Username of the packet correctly" do
      packet.password.should == 'pass0123456789'
      packet.password.encoding.to_s.should == 'UTF-8'
    end
  end

  describe "when parsing packet with an unknown protocol name" do
    it "should throw a protocol exception" do
      lambda {
        packet = MQTT::Packet.parse(
          "\x10\x16\x00\x06FooBar\x03\x00\x00\x0a\x00\x08myclient"
        )
      }.should raise_error(
        MQTT::ProtocolException,
        "Unsupported protocol name: FooBar"
      )
    end
  end

  describe "when parsing packet with an unknown protocol version" do
    it "should throw a protocol exception" do
      lambda {
        packet = MQTT::Packet.parse(
          "\x10\x16\x00\x06MQIsdp\x02\x00\x00\x0a\x00\x08myclient"
        )
      }.should raise_error(
        MQTT::ProtocolException,
        "Unsupported protocol version: 2"
      )
    end
  end

  describe "when calling the inspect method" do
    it "should output correct string for the default options" do
      packet = MQTT::Packet::Connect.new
      packet.inspect.should == "#<MQTT::Packet::Connect: keep_alive=15, clean, client_id=''>"
    end

    it "should output correct string when parameters are given" do
      packet = MQTT::Packet::Connect.new(
        :keep_alive => 10,
        :client_id => 'c123',
        :clean_session => false,
        :username => 'foo'
      )
      packet.inspect.should == "#<MQTT::Packet::Connect: keep_alive=10, client_id='c123', username='foo'>"
    end
  end
end

describe MQTT::Packet::Connack do
  describe "when serialising a packet" do
    it "should output the correct bytes for a sucessful connection acknowledgement packet" do
      packet = MQTT::Packet::Connack.new( :return_code => 0x00 )
      packet.to_s.should == "\x20\x02\x00\x00"
    end
  end

  describe "when parsing a successful Connection Accepted packet" do
    let(:packet) do
      MQTT::Packet.parse( "\x20\x02\x00\x00" )
    end

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Connack
    end

    it "should set the QOS of the packet correctly" do
      packet.qos.should == 0
    end

    it "should set the return code of the packet correctly" do
      packet.return_code.should == 0x00
    end

    it "should set the return message of the packet correctly" do
      packet.return_msg.should match(/Connection Accepted/i)
    end
  end

  describe "when parsing a unacceptable protocol version packet" do
    let(:packet) do
      MQTT::Packet.parse( "\x20\x02\x00\x01" )
    end

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      packet.return_code.should == 0x01
    end

    it "should set the return message of the packet correctly" do
      packet.return_msg.should match(/unacceptable protocol version/i)
    end
  end

  describe "when parsing a client identifier rejected packet" do
    let(:packet) { MQTT::Packet.parse( "\x20\x02\x00\x02" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      packet.return_code.should == 0x02
    end

    it "should set the return message of the packet correctly" do
      packet.return_msg.should match(/client identifier rejected/i)
    end
  end

  describe "when parsing a broker unavailable packet" do
    let(:packet) do
      MQTT::Packet.parse( "\x20\x02\x00\x03" )
    end

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      packet.return_code.should == 0x03
    end

    it "should set the return message of the packet correctly" do
      packet.return_msg.should match(/broker unavailable/i)
    end
  end

  describe "when parsing a broker unavailable packet" do
    let(:packet) do
      MQTT::Packet.parse( "\x20\x02\x00\x04" )
    end

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      packet.return_code.should == 0x04
    end

    it "should set the return message of the packet correctly" do
      packet.return_msg.should match(/bad user name or password/i)
    end
  end

  describe "when parsing a broker unavailable packet" do
    let(:packet) do
      MQTT::Packet.parse( "\x20\x02\x00\x05" )
    end

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      packet.return_code.should == 0x05
    end

    it "should set the return message of the packet correctly" do
      packet.return_msg.should match(/not authorised/i)
    end
  end

  describe "when parsing an unknown connection refused packet" do
    let(:packet) { MQTT::Packet.parse( "\x20\x02\x00\x10" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      packet.return_code.should == 0x10
    end

    it "should set the return message of the packet correctly" do
      packet.return_msg.should match(/Connection refused: error code 16/i)
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        packet = MQTT::Packet.parse( "\x20\x03\x00\x00\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Connect Acknowledgment packet"
      )
    end
  end

  describe "when calling the inspect method" do
    it "should output the right string when the return code is 0" do
      packet = MQTT::Packet::Connack.new( :return_code => 0x00 )
      packet.inspect.should == "#<MQTT::Packet::Connack: 0x00>"
    end
    it "should output the right string when the return code is 0x0F" do
      packet = MQTT::Packet::Connack.new( :return_code => 0x0F )
      packet.inspect.should == "#<MQTT::Packet::Connack: 0x0F>"
    end
  end
end

describe MQTT::Packet::Puback do
  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with no flags" do
      packet = MQTT::Packet::Puback.new( :message_id => 0x1234 )
      packet.to_s.should == "\x40\x02\x12\x34"
    end
  end

  describe "when parsing a packet" do
    let(:packet) { MQTT::Packet.parse( "\x40\x02\x12\x34" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Puback
    end

    it "should set the message id of the packet correctly" do
      packet.message_id.should == 0x1234
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        packet = MQTT::Packet.parse( "\x40\x03\x12\x34\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Publish Acknowledgment packet"
      )
    end
  end

  it "should output the right string when calling inspect" do
    packet = MQTT::Packet::Puback.new( :message_id => 0x1234 )
    packet.inspect.should == "#<MQTT::Packet::Puback: 0x1234>"
  end
end

describe MQTT::Packet::Pubrec do
  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with no flags" do
      packet = MQTT::Packet::Pubrec.new( :message_id => 0x1234 )
      packet.to_s.should == "\x50\x02\x12\x34"
    end
  end

  describe "when parsing a packet" do
    let(:packet) { MQTT::Packet.parse( "\x50\x02\x12\x34" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Pubrec
    end

    it "should set the message id of the packet correctly" do
      packet.message_id.should == 0x1234
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        packet = MQTT::Packet.parse( "\x50\x03\x12\x34\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Publish Received packet"
      )
    end
  end

  it "should output the right string when calling inspect" do
    packet = MQTT::Packet::Pubrec.new( :message_id => 0x1234 )
    packet.inspect.should == "#<MQTT::Packet::Pubrec: 0x1234>"
  end
end

describe MQTT::Packet::Pubrel do
  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with no flags" do
      packet = MQTT::Packet::Pubrel.new( :message_id => 0x1234 )
      packet.to_s.should == "\x60\x02\x12\x34"
    end
  end

  describe "when parsing a packet" do
    let(:packet) { MQTT::Packet.parse( "\x60\x02\x12\x34" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Pubrel
    end

    it "should set the message id of the packet correctly" do
      packet.message_id.should == 0x1234
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        packet = MQTT::Packet.parse( "\x60\x03\x12\x34\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Publish Release packet"
      )
    end
  end

  it "should output the right string when calling inspect" do
    packet = MQTT::Packet::Pubrel.new( :message_id => 0x1234 )
    packet.inspect.should == "#<MQTT::Packet::Pubrel: 0x1234>"
  end
end

describe MQTT::Packet::Pubcomp do
  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with no flags" do
      packet = MQTT::Packet::Pubcomp.new( :message_id => 0x1234 )
      packet.to_s.should == "\x70\x02\x12\x34"
    end
  end

  describe "when parsing a packet" do
    let(:packet) { MQTT::Packet.parse( "\x70\x02\x12\x34" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Pubcomp
    end

    it "should set the message id of the packet correctly" do
      packet.message_id.should == 0x1234
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        MQTT::Packet.parse( "\x70\x03\x12\x34\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Publish Complete packet"
      )
    end
  end

  it "should output the right string when calling inspect" do
    packet = MQTT::Packet::Pubcomp.new( :message_id => 0x1234 )
    packet.inspect.should == "#<MQTT::Packet::Pubcomp: 0x1234>"
  end
end

describe MQTT::Packet::Subscribe do
  describe "setting the packet's topics" do
    let(:packet)  { MQTT::Packet::Subscribe.new }

    it "should be able to set the topics from a String 'a/b'" do
      packet.topics = 'a/b'
      packet.topics.should == [["a/b", 0]]
    end

    it "should be able to set the multiple topics from an array ['a/b', 'b/c']" do
      packet.topics = ['a/b', 'b/c']
      packet.topics.should == [["a/b", 0], ['b/c', 0]]
    end

    it "should be able to set the topics from a Hash {'a/b' => 0, 'b/c' => 1}" do
      packet.topics = {'a/b' => 0, 'b/c' => 1}
      packet.topics.should == [["a/b", 0], ["b/c", 1]]
    end

    it "should be able to set the topics from a single level array ['a/b', 0]" do
      packet.topics = ['a/b', 0]
      packet.topics.should == [["a/b", 0]]
    end

    it "should be able to set the topics from a two level array [['a/b' => 0], ['b/c' => 1]]" do
      packet.topics = [['a/b', 0], ['b/c', 1]]
      packet.topics.should == [['a/b', 0], ['b/c', 1]]
    end

    it "should throw an exception when setting topic with a non-string" do
      lambda {
        packet.topics = 56
      }.should raise_error(
        'Invalid topics input: 56'
      )
    end
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with a single topic" do
      packet = MQTT::Packet::Subscribe.new( :topics => 'a/b', :message_id => 1 )
      packet.to_s.should == "\x82\x08\x00\x01\x00\x03a/b\x00"
    end

    it "should output the correct bytes for a packet with multiple topics" do
      packet = MQTT::Packet::Subscribe.new( :topics => [['a/b', 0], ['c/d', 1]], :message_id => 6 )
      packet.to_s.should == "\x82\x0e\000\x06\x00\x03a/b\x00\x00\x03c/d\x01"
    end

    it "should throw an exception when no topics are given" do
      lambda {
        MQTT::Packet::Subscribe.new.to_s
      }.should raise_error(
        'no topics given when serialising packet'
      )
    end
  end

  describe "when parsing a packet with a single topic" do
    let(:packet) { MQTT::Packet.parse( "\x82\x08\x00\x01\x00\x03a/b\x00" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Subscribe
    end

    it "should set the QOS level correctly" do
      packet.qos.should == 1
    end

    it "should set the Message ID correctly" do
      packet.message_id.should == 1
    end

    it "should set the topic name correctly" do
      packet.topics.should == [['a/b',0]]
    end
  end

  describe "when parsing a packet with a two topics" do
    let(:packet) { MQTT::Packet.parse( "\x82\x0e\000\x06\x00\x03a/b\x00\x00\x03c/d\x01" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Subscribe
    end

    it "should set the QOS level correctly" do
      packet.qos.should == 1
    end

    it "should set the Message ID correctly" do
      packet.message_id.should == 6
    end

    it "should set the topic name correctly" do
      packet.topics.should == [['a/b',0],['c/d',1]]
    end
  end

  describe "when calling the inspect method" do
    it "should output correct string for a single topic" do
      packet = MQTT::Packet::Subscribe.new(:topics => 'test')
      packet.inspect.should == "#<MQTT::Packet::Subscribe: 0x00, 'test':0>"
    end

    it "should output correct string for multiple topics" do
      packet = MQTT::Packet::Subscribe.new(:topics => {'a' => 1, 'b' => 0, 'c' => 2})
      packet.inspect.should == "#<MQTT::Packet::Subscribe: 0x00, 'a':1, 'b':0, 'c':2>"
    end
  end
end

describe MQTT::Packet::Suback do
  describe "when serialising a packet" do
    it "should output the correct bytes for an acknowledgement to a single topic" do
      packet = MQTT::Packet::Suback.new( :granted_qos => 0, :message_id => 5 )
      packet.to_s.should == "\x90\x03\x00\x05\x00"
    end

    it "should output the correct bytes for an acknowledgement to a two topics" do
      packet = MQTT::Packet::Suback.new( :granted_qos => [0,1], :message_id => 6 )
      packet.to_s.should == "\x90\x04\x00\x06\x00\x01"
    end

    it "should throw an exception when no granted QOSs are given" do
      lambda {
        MQTT::Packet::Suback.new(:message_id => 7).to_s
      }.should raise_error(
        'no granted QOS given when serialising packet'
      )
    end

    it "should throw an exception if the granted QOS is not an integer" do
      lambda {
        MQTT::Packet::Suback.new(:granted_qos => :foo, :message_id => 8).to_s
      }.should raise_error(
        'granted QOS should be an integer or an array of QOS levels'
      )
    end
  end

  describe "when parsing a packet with a single QOS value of 0" do
    let(:packet) { MQTT::Packet.parse( "\x90\x03\x12\x34\x00" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Suback
    end

    it "should set the message id of the packet correctly" do
      packet.message_id.should == 0x1234
    end

    it "should set the Granted QOS of the packet correctly" do
      packet.granted_qos.should == [0]
    end
  end

  describe "when parsing a packet with two QOS values" do
    let(:packet) { MQTT::Packet.parse( "\x90\x04\x12\x34\x01\x01" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Suback
    end

    it "should set the message id of the packet correctly" do
      packet.message_id.should == 0x1234
    end

    it "should set the Granted QOS of the packet correctly" do
      packet.granted_qos.should == [1,1]
    end
  end

  describe "when calling the inspect method" do
    it "should output correct string for a single granted qos" do
      packet = MQTT::Packet::Suback.new(:message_id => 0x1234, :granted_qos => 0)
      packet.inspect.should == "#<MQTT::Packet::Suback: 0x1234, qos=0>"
    end

    it "should output correct string for multiple topics" do
      packet = MQTT::Packet::Suback.new(:message_id => 0x1235, :granted_qos => [0,1,2])
      packet.inspect.should == "#<MQTT::Packet::Suback: 0x1235, qos=0,1,2>"
    end
  end
end

describe MQTT::Packet::Unsubscribe do
  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with single topic" do
      packet = MQTT::Packet::Unsubscribe.new( :topics => 'a/b', :message_id => 5 )
      packet.to_s.should == "\xa2\x07\x00\x05\x00\x03a/b"
    end

    it "should output the correct bytes for a packet with multiple topics" do
      packet = MQTT::Packet::Unsubscribe.new( :topics => ['a/b','c/d'], :message_id => 6 )
      packet.to_s.should == "\xa2\x0c\000\006\000\003a/b\000\003c/d"
    end

    it "should throw an exception when no topics are given" do
      lambda {
        MQTT::Packet::Unsubscribe.new.to_s
      }.should raise_error(
        'no topics given when serialising packet'
      )
    end
  end

  describe "when parsing a packet" do
    let(:packet) { MQTT::Packet.parse( "\xa2\f\000\005\000\003a/b\000\003c/d" ) }

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Unsubscribe
    end

    it "should set the QOS level correctly" do
      packet.qos.should == 1
    end

    it "should set the topic name correctly" do
      packet.topics.should == ['a/b','c/d']
    end
  end

  describe "when calling the inspect method" do
    it "should output correct string for a single topic" do
      packet = MQTT::Packet::Unsubscribe.new(:topics => 'test')
      packet.inspect.should == "#<MQTT::Packet::Unsubscribe: 0x00, 'test'>"
    end

    it "should output correct string for multiple topics" do
      packet = MQTT::Packet::Unsubscribe.new(:message_id => 42, :topics => ['a', 'b', 'c'])
      packet.inspect.should == "#<MQTT::Packet::Unsubscribe: 0x2A, 'a', 'b', 'c'>"
    end
  end
end

describe MQTT::Packet::Unsuback do
  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with no flags" do
      packet = MQTT::Packet::Unsuback.new( :message_id => 0x1234 )
      packet.to_s.should == "\xB0\x02\x12\x34"
    end
  end

  describe "when parsing a packet" do
    let(:packet) do
      MQTT::Packet.parse( "\xB0\x02\x12\x34" )
    end

    it "should correctly create the right type of packet object" do
      packet.class.should == MQTT::Packet::Unsuback
    end

    it "should set the message id of the packet correctly" do
      packet.message_id.should == 0x1234
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        packet = MQTT::Packet.parse( "\xB0\x03\x12\x34\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Unsubscribe Acknowledgment packet"
      )
    end
  end

  it "should output the right string when calling inspect" do
    packet = MQTT::Packet::Unsuback.new( :message_id => 0x1234 )
    packet.inspect.should == "#<MQTT::Packet::Unsuback: 0x1234>"
  end
end

describe MQTT::Packet::Pingreq do
  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with no flags" do
      packet = MQTT::Packet::Pingreq.new
      packet.to_s.should == "\xC0\x00"
    end
  end

  describe "when parsing a packet" do
    it "should correctly create the right type of packet object" do
      packet = MQTT::Packet.parse( "\xC0\x00" )
      packet.class.should == MQTT::Packet::Pingreq
    end

    it "should throw an exception if the packet has a payload" do
      lambda {
        MQTT::Packet.parse( "\xC0\x05hello" )
      }.should raise_error(
        'Extra bytes at end of Ping Request packet'
      )
    end
  end

  it "should output the right string when calling inspect" do
    packet = MQTT::Packet::Pingreq.new
    packet.inspect.should == "#<MQTT::Packet::Pingreq>"
  end
end

describe MQTT::Packet::Pingresp do
  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with no flags" do
      packet = MQTT::Packet::Pingresp.new
      packet.to_s.should == "\xD0\x00"
    end
  end

  describe "when parsing a packet" do
    it "should correctly create the right type of packet object" do
      packet = MQTT::Packet.parse( "\xD0\x00" )
      packet.class.should == MQTT::Packet::Pingresp
    end

    it "should throw an exception if the packet has a payload" do
      lambda {
        MQTT::Packet.parse( "\xD0\x05hello" )
      }.should raise_error(
        'Extra bytes at end of Ping Response packet'
      )
    end
  end

  it "should output the right string when calling inspect" do
    packet = MQTT::Packet::Pingresp.new
    packet.inspect.should == "#<MQTT::Packet::Pingresp>"
  end
end


describe MQTT::Packet::Disconnect do
  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with no flags" do
      packet = MQTT::Packet::Disconnect.new
      packet.to_s.should == "\xE0\x00"
    end
  end

  describe "when parsing a packet" do
    it "should correctly create the right type of packet object" do
      packet = MQTT::Packet.parse( "\xE0\x00" )
      packet.class.should == MQTT::Packet::Disconnect
    end

    it "should throw an exception if the packet has a payload" do
      lambda {
        MQTT::Packet.parse( "\xE0\x05hello" )
      }.should raise_error(
        'Extra bytes at end of Disconnect packet'
      )
    end
  end

  it "should output the right string when calling inspect" do
    packet = MQTT::Packet::Disconnect.new
    packet.inspect.should == "#<MQTT::Packet::Disconnect>"
  end
end


describe "Serialising an invalid packet" do
  context "that has a no type" do
    it "should throw an exception" do
      lambda {
        MQTT::Packet.new.to_s
      }.should raise_error(
        RuntimeError,
        "Invalid packet type: MQTT::Packet"
      )
    end
  end
end

describe "Reading in an invalid packet from a socket" do
  context "that has 0 length" do
    it "should throw an exception" do
      lambda {
        socket = StringIO.new
        MQTT::Packet.read(socket)
      }.should raise_error(
        MQTT::ProtocolException,
        "Failed to read byte from socket"
      )
    end
  end

  context "that has an incomplete packet length header" do
    it "should throw an exception" do
      lambda {
        socket = StringIO.new("\x30\xFF")
        MQTT::Packet.read(socket)
      }.should raise_error(
        MQTT::ProtocolException,
        "Failed to read byte from socket"
      )
    end
  end

  context "that has the maximum number of bytes in the length header" do
    it "should throw an exception" do
      lambda {
        socket = StringIO.new("\x30\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF")
        MQTT::Packet.read(socket)
      }.should raise_error(
        MQTT::ProtocolException,
        "Failed to parse packet - input buffer (4) is not the same as the body length header (268435455)"
      )
    end
  end
end

describe "Parsing an invalid packet" do
  context "that has no length" do
    it "should throw an exception" do
      lambda {
        MQTT::Packet.parse( "" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Invalid packet: less than 2 bytes long"
      )
    end
  end

  context "that has an invalid type identifier" do
    it "should throw an exception" do
      lambda {
        MQTT::Packet.parse( "\x00\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Invalid packet type identifier: 0"
      )
    end
  end

  context "that has an incomplete packet length header" do
    it "should throw an exception" do
      lambda {
        MQTT::Packet.parse( "\x30\xFF" )
      }.should raise_error(
        MQTT::ProtocolException,
        "The packet length header is incomplete"
      )
    end
  end

  context "that has too many bytes in the length field" do
    it "should throw an exception" do
      lambda {
        MQTT::Packet.parse( "\x30\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" )
      }.should raise_error(
        MQTT::ProtocolException,
        'Failed to parse packet - input buffer (4) is not the same as the body length header (268435455)'
      )
    end
  end

  context "that has a bigger buffer than expected" do
    it "should throw an exception" do
      lambda {
        MQTT::Packet.parse( "\x30\x11\x00\x04testhello big world" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Failed to parse packet - input buffer (21) is not the same as the body length header (17)"
      )
    end
  end

  context "that has a smaller buffer than expected" do
    it "should throw an exception" do
      lambda {
        MQTT::Packet.parse( "\x30\x11\x00\x04testhello" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Failed to parse packet - input buffer (11) is not the same as the body length header (17)"
      )
    end
  end
end
