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
  end

  describe "when setting packet parameters" do
    before(:each) do
      @packet = MQTT::Packet.new(
        :duplicate => false,
        :qos => 0,
        :retain => false
      )
    end

    it "should have a type_id method to get the integer ID of the packet type" do
      @packet = MQTT::Packet::Pingreq.new
      @packet.type_id.should == 12
    end

    it "should let you change the dup flag of a packet" do
      @packet.duplicate = true
      @packet.duplicate.should be_true
    end

    it "should let you change the dup flag of a packet using an integer" do
      @packet.duplicate = 1
      @packet.duplicate.should be_true
    end

    it "should let you change the retain flag of a packet" do
      @packet.retain = true
      @packet.retain.should be_true
    end

    it "should let you change the retain flag of a packet using an integer" do
      @packet.retain = 1
      @packet.retain.should be_true
    end
  end

  it "should let you attributes using the update_attributes method" do
    @packet = MQTT::Packet.new(:qos => 1)
    @packet.update_attributes(:qos => 2)
    @packet.qos.should == 2
  end

  describe "protected methods" do
    before(:each) do
      @packet = MQTT::Packet.new
    end

    it "should provide a encode_bytes method to get some bytes as Integers" do
      data = @packet.send(:encode_bytes, 0x48, 0x65, 0x6c, 0x6c, 'o'.unpack('C1')[0])
      data.should == 'Hello'
    end

    it "should provide a add_short method to get a big-endian unsigned 16-bit integer" do
      data = @packet.send(:encode_short, 1024)
      data.should == "\x04\x00"
    end

    it "should provide a add_string method to get a string preceeded by its length" do
      data = @packet.send(:encode_string, 'quack')
      data.should == "\x00\x05quack"
    end

    it "should provide a shift_short method to get a 16-bit unsigned integer" do
      buffer = "\x22\x8Bblahblah"
      @packet.send(:shift_short,buffer).should == 8843
      buffer.should == 'blahblah'
    end

    it "should provide a shift_byte method to get one byte as integers" do
      buffer = "\x01blahblah"
      @packet.send(:shift_byte,buffer).should == 1
      buffer.should == 'blahblah'
    end

    it "should provide a shift_string method to get a string preceeded by its length" do
      buffer = "\x00\x05Hello World"
      @packet.send(:shift_string,buffer).should == "Hello"
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

    it "should throw an exception when there is no topic name" do
      lambda {
        MQTT::Packet::Publish.new.to_s
      }.should raise_error(
        'Invalid topic name when serialising packet'
      )
    end
  end

  describe "when parsing a packet with QOS 0" do
    before(:each) do
      @packet = MQTT::Packet.parse( "\x30\x11\x00\x04testhello world" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Publish
    end

    it "should set the QOS level correctly" do
      @packet.qos.should == 0
    end

    it "should set the RETAIN flag correctly" do
      @packet.retain.should be_false
    end

    it "should set the DUP flag correctly" do
      @packet.duplicate.should be_false
    end

    it "should set the topic name correctly" do
      @packet.topic.should == 'test'
    end

    it "should set the payload correctly" do
      @packet.payload.should == 'hello world'
    end
  end

  describe "when parsing a packet with QOS 2 and retain and dup flags set" do
    before(:each) do
      @packet = MQTT::Packet.parse( "\x3D\x12\x00\x03c/d\x00\x05hello world" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Publish
    end

    it "should set the QOS level correctly" do
      @packet.qos.should == 2
    end

    it "should set the RETAIN flag correctly" do
      @packet.retain.should be_true
    end

    it "should set the DUP flag correctly" do
      @packet.duplicate.should be_true
    end

    it "should set the topic name correctly" do
      @packet.topic.should == 'c/d'
    end

    it "should set the payload correctly" do
      @packet.payload.should == 'hello world'
    end
  end

  describe "when parsing a packet with a body of 314 bytes" do
    before(:each) do
      # 0x30 = publish
      # 0xC1 = (65 * 1)
      # 0x02 = (2 * 128)
      @packet = MQTT::Packet.parse( "\x30\xC1\x02\x00\x05topic" + ('x' * 314) )
    end

    it "should parse the packet type correctly" do
      @packet.class.should == MQTT::Packet::Publish
    end

    it "should get the topic name correctly" do
      @packet.topic.should == 'topic'
    end

    it "should get the body length correctly" do
      @packet.payload.size.should == 314
    end
  end

  describe "when parsing a packet with a body of 16kbytes" do
    before(:each) do
      # 0x30 = publish
      # 0x87 = (7 * 1)
      # 0x80 = (0 * 128)
      # 0x01 = (1 * 16384)
      @packet = MQTT::Packet.parse( "\x30\x87\x80\x01\x00\x05topic" + ('x'*16384) )
    end

    it "should parse the packet type correctly" do
      @packet.class.should == MQTT::Packet::Publish
    end

    it "should get the topic name correctly" do
      @packet.topic.should == 'topic'
    end

    it "should get the body length correctly" do
      @packet.payload.size.should == 16384
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
    before(:each) do
      @packet = MQTT::Packet.parse(
        "\x10\x16\x00\x06MQIsdp\x03\x00\x00\x0a\x00\x08myclient"
      )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Connect
    end

    it "should set the QOS of the packet correctly" do
      @packet.qos.should == 0
    end

    it "should set the Protocol Name of the packet correctly" do
      @packet.protocol_name.should == 'MQIsdp'
    end

    it "should set the Protocol Version of the packet correctly" do
      @packet.protocol_version.should == 3
    end

    it "should set the Client Identifier of the packet correctly" do
      @packet.client_id.should == 'myclient'
    end

    it "should set the Keep Alive timer of the packet correctly" do
      @packet.keep_alive.should == 10
    end

    it "should set not have the clean session flag set" do
      @packet.clean_session.should be_false
    end

    it "should set the the username field of the packet to nil" do
      @packet.username.should be_nil
    end

    it "should set the the password field of the packet to nil" do
      @packet.password.should be_nil
    end
  end

  describe "when parsing a Connect packet with the clean session flag set" do
    before(:each) do
      @packet = MQTT::Packet.parse(
        "\x10\x16\x00\x06MQIsdp\x03\x02\x00\x0a\x00\x08myclient"
      )
    end

    it "should set the clean session flag" do
      @packet.clean_session.should be_true
    end
  end

  describe "when parsing a Connect packet with a Will and Testament" do
    before(:each) do
      @packet = MQTT::Packet.parse(
        "\x10\x24\x00\x06MQIsdp\x03\x0e\x00\x0a\x00\x08myclient\x00\x05topic\x00\x05hello"
      )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Connect
    end

    it "should set the QOS of the packet correctly" do
      @packet.qos.should == 0
    end

    it "should set the Protocol Name of the packet correctly" do
      @packet.protocol_name.should == 'MQIsdp'
    end

    it "should set the Protocol Version of the packet correctly" do
      @packet.protocol_version.should == 3
    end

    it "should set the Client Identifier of the packet correctly" do
      @packet.client_id.should == 'myclient'
    end

    it "should set the clean session flag should be set" do
      @packet.clean_session.should be_true
    end

    it "should set the QOS of the Will should be 1" do
      @packet.will_qos.should == 1
    end

    it "should set the Will retain flag should be false" do
      @packet.will_retain.should be_false
    end

    it "should set the Will topic of the packet correctly" do
      @packet.will_topic.should == 'topic'
    end

    it "should set the Will payload of the packet correctly" do
      @packet.will_payload.should == 'hello'
    end
  end

  describe "when parsing a Connect packet with a username and password" do
    before(:each) do
      @packet = MQTT::Packet.parse(
        "\x10\x2A"+
        "\x00\x06MQIsdp"+
        "\x03\xC0\x00\x0a"+
        "\x00\x08myclient"+
        "\x00\x08username"+
        "\x00\x08password"
      )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Connect
    end

    it "should set the QOS of the packet correctly" do
      @packet.qos.should == 0
    end

    it "should set the Protocol Name of the packet correctly" do
      @packet.protocol_name.should == 'MQIsdp'
    end

    it "should set the Protocol Version of the packet correctly" do
      @packet.protocol_version.should == 3
    end

    it "should set the Client Identifier of the packet correctly" do
      @packet.client_id.should == 'myclient'
    end

    it "should set the Keep Alive Timer of the packet correctly" do
      @packet.keep_alive.should == 10
    end

    it "should set the Username of the packet correctly" do
      @packet.username.should == 'username'
    end

    it "should set the Username of the packet correctly" do
      @packet.password.should == 'password'
    end
  end

  describe "when parsing a Connect that has a username but no password" do
    before(:each) do
      @packet = MQTT::Packet.parse(
        "\x10\x20\x00\x06MQIsdp\x03\x80\x00\x0a\x00\x08myclient\x00\x08username"
      )
    end

    it "should set the Username of the packet correctly" do
      @packet.username.should == 'username'
    end

    it "should set the Username of the packet correctly" do
      @packet.password.should be_nil
    end
  end

  describe "when parsing a Connect that has a password but no username" do
    before(:each) do
      @packet = MQTT::Packet.parse(
        "\x10\x20\x00\x06MQIsdp\x03\x40\x00\x0a\x00\x08myclient\x00\x08password"
      )
    end

    it "should set the Username of the packet correctly" do
      @packet.username.should be_nil
    end

    it "should set the Username of the packet correctly" do
      @packet.password.should == 'password'
    end
  end

  describe "when parsing a Connect packet has the username and password flags set but doesn't have the fields" do
    before(:each) do
      @packet = MQTT::Packet.parse(
        "\x10\x16\x00\x06MQIsdp\x03\xC0\x00\x0a\x00\x08myclient"
      )
    end

    it "should set the Username of the packet correctly" do
      @packet.username.should be_nil
    end

    it "should set the Username of the packet correctly" do
      @packet.password.should be_nil
    end
  end

  describe "when parsing a Connect packet with every option set" do
    before(:each) do
      @packet = MQTT::Packet.parse(
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
      @packet.class.should == MQTT::Packet::Connect
    end

    it "should set the QOS of the packet correctly" do
      @packet.qos.should == 0
    end

    it "should set the Protocol Name of the packet correctly" do
      @packet.protocol_name.should == 'MQIsdp'
    end

    it "should set the Protocol Version of the packet correctly" do
      @packet.protocol_version.should == 3
    end

    it "should set the Keep Alive Timer of the packet correctly" do
      @packet.keep_alive.should == 65535
    end

    it "should set the Client Identifier of the packet correctly" do
      @packet.client_id.should == '12345678901234567890123'
    end

    it "should set the Will QoS of the packet correctly" do
      @packet.will_qos.should == 2
    end

    it "should set the Will retain flag of the packet correctly" do
      @packet.will_retain.should be_true
    end

    it "should set the Will topic of the packet correctly" do
      @packet.will_topic.should == 'will_topic'
    end

    it "should set the Will payload of the packet correctly" do
      @packet.will_payload.should == 'will_message'
    end

    it "should set the Username of the packet correctly" do
      @packet.username.should == 'user0123456789'
    end

    it "should set the Username of the packet correctly" do
      @packet.password.should == 'pass0123456789'
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
    before(:each) do
      @packet = MQTT::Packet.parse( "\x20\x02\x00\x00" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Connack
    end

    it "should set the QOS of the packet correctly" do
      @packet.qos.should == 0
    end

    it "should set the return code of the packet correctly" do
      @packet.return_code.should == 0x00
    end

    it "should set the return message of the packet correctly" do
      @packet.return_msg.should match(/Connection Accepted/i)
    end
  end

  describe "when parsing a unacceptable protocol version packet" do
    before(:each) do
      @packet = MQTT::Packet.parse( "\x20\x02\x00\x01" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      @packet.return_code.should == 0x01
    end

    it "should set the return message of the packet correctly" do
      @packet.return_msg.should match(/unacceptable protocol version/i)
    end
  end

  describe "when parsing a client identifier rejected packet" do
    before(:each) do
      @packet = MQTT::Packet.parse( "\x20\x02\x00\x02" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      @packet.return_code.should == 0x02
    end

    it "should set the return message of the packet correctly" do
      @packet.return_msg.should match(/client identifier rejected/i)
    end
  end

  describe "when parsing a broker unavailable packet" do
    before(:each) do
      @packet = MQTT::Packet.parse( "\x20\x02\x00\x03" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      @packet.return_code.should == 0x03
    end

    it "should set the return message of the packet correctly" do
      @packet.return_msg.should match(/broker unavailable/i)
    end
  end

  describe "when parsing a broker unavailable packet" do
    before(:each) do
      @packet = MQTT::Packet.parse( "\x20\x02\x00\x04" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      @packet.return_code.should == 0x04
    end

    it "should set the return message of the packet correctly" do
      @packet.return_msg.should match(/bad user name or password/i)
    end
  end

  describe "when parsing a broker unavailable packet" do
    before(:each) do
      @packet = MQTT::Packet.parse( "\x20\x02\x00\x05" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      @packet.return_code.should == 0x05
    end

    it "should set the return message of the packet correctly" do
      @packet.return_msg.should match(/not authorised/i)
    end
  end

  describe "when parsing an unknown connection refused packet" do
    before(:each) do
      @packet = MQTT::Packet.parse( "\x20\x02\x00\x10" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Connack
    end

    it "should set the return code of the packet correctly" do
      @packet.return_code.should == 0x10
    end

    it "should set the return message of the packet correctly" do
      @packet.return_msg.should match(/Connection refused: error code 16/i)
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        @packet = MQTT::Packet.parse( "\x20\x03\x00\x00\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Connect Acknowledgment packet"
      )
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
    before(:each) do
      @packet = MQTT::Packet.parse( "\x40\x02\x12\x34" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Puback
    end

    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        @packet = MQTT::Packet.parse( "\x40\x03\x12\x34\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Publish Acknowledgment packet"
      )
    end
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
    before(:each) do
      @packet = MQTT::Packet.parse( "\x50\x02\x12\x34" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Pubrec
    end

    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        @packet = MQTT::Packet.parse( "\x50\x03\x12\x34\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Publish Received packet"
      )
    end
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
    before(:each) do
      @packet = MQTT::Packet.parse( "\x60\x02\x12\x34" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Pubrel
    end

    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        @packet = MQTT::Packet.parse( "\x60\x03\x12\x34\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Publish Release packet"
      )
    end
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
    before(:each) do
      @packet = MQTT::Packet.parse( "\x70\x02\x12\x34" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Pubcomp
    end

    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        @packet = MQTT::Packet.parse( "\x70\x03\x12\x34\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Publish Complete packet"
      )
    end
  end
end

describe MQTT::Packet::Subscribe do
  describe "setting the packet's topics" do
    before(:each) do
      @packet = MQTT::Packet::Subscribe.new
    end

    it "should be able to set the topics from a String 'a/b'" do
      @packet.topics = 'a/b'
      @packet.topics.should == [["a/b", 0]]
    end

    it "should be able to set the multiple topics from an array ['a/b', 'b/c']" do
      @packet.topics = ['a/b', 'b/c']
      @packet.topics.should == [["a/b", 0], ['b/c', 0]]
    end

    it "should be able to set the topics from a Hash {'a/b' => 0, 'b/c' => 1}" do
      @packet.topics = {'a/b' => 0, 'b/c' => 1}
      @packet.topics.should == [["a/b", 0], ["b/c", 1]]
    end

    it "should be able to set the topics from a single level array ['a/b', 0]" do
      @packet.topics = ['a/b', 0]
      @packet.topics.should == [["a/b", 0]]
    end

    it "should be able to set the topics from a two level array [['a/b' => 0], ['b/c' => 1]]" do
      @packet.topics = [['a/b', 0], ['b/c', 1]]
      @packet.topics.should == [['a/b', 0], ['b/c', 1]]
    end

    it "should throw an exception when setting topic with a non-string" do
      lambda {
        @packet.topics = 56
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
    before(:each) do
      @packet = MQTT::Packet.parse( "\x82\x08\x00\x01\x00\x03a/b\x00" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Subscribe
    end

    it "should set the QOS level correctly" do
      @packet.qos.should == 1
    end

    it "should set the Message ID correctly" do
      @packet.message_id.should == 1
    end

    it "should set the topic name correctly" do
      @packet.topics.should == [['a/b',0]]
    end
  end

  describe "when parsing a packet with a two topics" do
    before(:each) do
      @packet = MQTT::Packet.parse( "\x82\x0e\000\x06\x00\x03a/b\x00\x00\x03c/d\x01" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Subscribe
    end

    it "should set the QOS level correctly" do
      @packet.qos.should == 1
    end

    it "should set the Message ID correctly" do
      @packet.message_id.should == 6
    end

    it "should set the topic name correctly" do
      @packet.topics.should == [['a/b',0],['c/d',1]]
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
    before(:each) do
      @packet = MQTT::Packet.parse( "\x90\x03\x12\x34\x00" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Suback
    end

    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
    end

    it "should set the Granted QOS of the packet correctly" do
      @packet.granted_qos.should == [0]
    end
  end

  describe "when parsing a packet with two QOS values" do
    before(:each) do
      @packet = MQTT::Packet.parse( "\x90\x04\x12\x34\x01\x01" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Suback
    end

    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
    end

    it "should set the Granted QOS of the packet correctly" do
      @packet.granted_qos.should == [1,1]
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
    before(:each) do
      @packet = MQTT::Packet.parse( "\xa2\f\000\005\000\003a/b\000\003c/d" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Unsubscribe
    end

    it "should set the QOS level correctly" do
      @packet.qos.should == 1
    end

    it "should set the topic name correctly" do
      @packet.topics.should == ['a/b','c/d']
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
    before(:each) do
      @packet = MQTT::Packet.parse( "\xB0\x02\x12\x34" )
    end

    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Unsuback
    end

    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
    end
  end

  describe "when parsing packet with extra bytes on the end" do
    it "should throw an exception" do
      lambda {
        @packet = MQTT::Packet.parse( "\xB0\x03\x12\x34\x00" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Extra bytes at end of Unsubscribe Acknowledgment packet"
      )
    end
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

describe "Reading in an invalid packet" do 
  context "that has 0 length" do
    it "should throw an exception" do
      lambda {
        data = StringIO.new
        MQTT::Packet.read(data)
      }.should raise_error(
        MQTT::ProtocolException
      )
    end
  end
end

describe "Parsing an invalid packet" do
  context "that has an invalid type identifier" do
    it "should throw an exception" do
      lambda {
        MQTT::Packet.parse( "\x00" )
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

  context "that has a bigger buffer than expected" do
    it "should throw an exception" do
      lambda {
        MQTT::Packet.parse( "\x30\x11\x00\x04testhello big world" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Failed to parse packet - input buffer (21) is not the same as the body length buffer (17)"
      )
    end
  end

  context "that has a smaller buffer than expected" do
    it "should throw an exception" do
      lambda {
        MQTT::Packet.parse( "\x30\x11\x00\x04testhello" )
      }.should raise_error(
        MQTT::ProtocolException,
        "Failed to parse packet - input buffer (11) is not the same as the body length buffer (17)"
      )
    end
  end
end
