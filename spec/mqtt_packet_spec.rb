$:.unshift(File.dirname(__FILE__))

require 'spec_helper'
require 'mqtt/packet'

describe MQTT::Packet do

  describe "when creating a new packet" do
    it "should allow you to set the packet dup flag as a hash parameter" do
      packet = MQTT::Packet.new( :dup => true )
      packet.dup.should == true
    end
  
    it "should allow you to set the packet QOS level as a hash parameter" do
      packet = MQTT::Packet.new( :qos => 2 )
      packet.qos.should == 2
    end
  
    it "should allow you to set the packet retain flag as a hash parameter" do
      packet = MQTT::Packet.new( :retain => true )
      packet.retain.should == true
    end
  end   
  
  describe "when setting packet parameters" do
    before(:each) do
      @packet = MQTT::Packet.new(
        :dup => false,
        :qos => 0,
        :retain => false
      )
    end
    
    it "should have a type_id method to get the integer ID of the packet type" do
      @packet = MQTT::Packet::Pingreq.new
      @packet.type_id.should == 12
    end
    
    it "should let you change the dup flag of a packet" do
      @packet.dup = true
      @packet.dup.should == true
    end
    
    it "should let you change the dup flag of a packet using an integer" do
      @packet.dup = 1
      @packet.dup.should == true
    end
    
    it "should let you change the retain flag of a packet" do
      @packet.retain = true
      @packet.retain.should == true
    end
    
    it "should let you change the retain flag of a packet using an integer" do
      @packet.retain = 1
      @packet.retain.should == true
    end
  end
  
  
  describe "protected methods" do
    before(:each) do
      @packet = MQTT::Packet.new
    end

    it "should provide a encode_bytes method to get some bytes as Integers" do
      data = @packet.send(:encode_bytes,0x48, 0x65, 0x6c, 0x6c, ?o)
      data.should == 'Hello'
    end

    it "should provide a add_short method to get a big-endian unsigned 16-bit integer" do
      data = @packet.send(:encode_short,1024)
      data.should == "\x04\x00"
    end

    it "should provide a add_string method to get a string preceeded by its length" do
      data = @packet.send(:encode_string,'quack')
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
      packet = MQTT::Packet::Publish.new( :qos => 2, :dup => true, :message_id => 5, :topic => 'c/d', :payload => 'hello world' )
      packet.to_s.should == "\x3C\x12\x00\x03c/d\x00\x05hello world"
    end
    
    it "should throw an exception when there is no topic name" do
      lambda { MQTT::Packet::Publish.new.to_s }.should raise_error
    end
  end
  
  describe "when reading and deserialising a packet with QOS 0 from a socket" do
    before(:each) do
      @io = StringIO.new("\x30\x11\x00\x04testhello world")
      @packet = MQTT::Packet.read( @io )
    end
    
    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Publish
    end
    
    it "should set the QOS level correctly" do
      @packet.qos.should == 0
    end
    
    it "should set the RETAIN flag correctly" do
      @packet.retain.should == false
    end
    
    it "should set the DUP flag correctly" do
      @packet.dup.should == false
    end
    
    it "should set the topic name correctly" do
      @packet.topic.should == 'test'
    end
    
    it "should set the payload correctly" do
      @packet.payload.should == 'hello world'
    end
  end
  
  describe "when reading and deserialising a packet with QOS 2 and retain and dup flags set from a socket" do
    before(:each) do
      @io = StringIO.new("\x3D\x12\x00\x03c/d\x00\x05hello world")
      @packet = MQTT::Packet.read( @io )
    end
    
    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Publish
    end
    
    it "should set the QOS level correctly" do
      @packet.qos.should == 2
    end
    
    it "should set the RETAIN flag correctly" do
      @packet.retain.should == true
    end
    
    it "should set the DUP flag correctly" do
      @packet.dup.should == true
    end
    
    it "should set the topic name correctly" do
      @packet.topic.should == 'c/d'
    end
    
    it "should set the payload correctly" do
      @packet.payload.should == 'hello world'
    end
  end

  describe "when reading and deserialising a packet with a body of 314 bytes" do
    before(:each) do
      # 0x30 = publish
      # 0xC1 = (65 * 1)
      # 0x02 = (2 * 128)
      @io = StringIO.new("\x30\xC1\x02\x00\x05topic" + ('x' * 314) + 'more data')
      @packet = MQTT::Packet.read( @io )
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

  describe "when reading and deserialising a packet with a body of 16kbytes" do
    before(:each) do
      # 0x30 = publish
      # 0x87 = (7 * 1)
      # 0x80 = (0 * 128)
      # 0x01 = (1 * 16384)
      @io = StringIO.new("\x30\x87\x80\x01\x00\x05topic" + ('x'*16384) + 'more data')
      @packet = MQTT::Packet.read( @io )
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
      packet.to_s.should == "\020\026\x00\x06MQIsdp\x03\x00\x00\x0a\x00\x08myclient"
    end
    
    it "should throw an exception when there is no client identifier" do
      lambda { MQTT::Packet::Connect.new.to_s }.should raise_error
    end
  end
  
  describe "when reading and deserialising a simple Connect packet from a socket" do
    before(:each) do
      @io = StringIO.new("\x10\x16\x00\x06MQIsdp\x03\x00\x00\x0a\x00\x08myclient")
      @packet = MQTT::Packet.read( @io )
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
    
    it "should set the Client Identifier of the packet correctly" do
      @packet.keep_alive.should == 10
    end
  end

#   describe "when reading and deserialising a Connect packet with a Will and Testament from a socket" do
#     before(:each) do
#       @io = StringIO.new("\x10\x24\x00\x06MQIsdp\x03\x0e\x00\x0a\x00\x08myclient\x00\x05topic\x00\x05hello")
#       @packet = MQTT::Packet.read( @io )
#     end
#     
#     it "should correctly create the right type of packet object" do
#       @packet.class.should == MQTT::Packet::Connect
#     end
#     
#     it "should set the QOS of the packet correctly" do
#       @packet.qos.should == 0
#     end
#     
#     it "should set the Protocol Name of the packet correctly" do
#       @packet.protocol_name.should == 'MQIsdp'
#     end
#     
#     it "should set the Protocol Version of the packet correctly" do
#       @packet.protocol_version.should == 3
#     end
#     
#     it "should set the Client Identifier of the packet correctly" do
#       @packet.client_id.should == 'myclient'
#     end
#     
#     it "should set the Client Identifier of the packet correctly" do
#       @packet.will_qos.should == 1
#     end
#     
#     it "should set the Client Identifier of the packet correctly" do
#       @packet.will_topic.should == 'topic'
#     end
#     
#     it "should set the Client Identifier of the packet correctly" do
#       @packet.will_payload.should == 'hello'
#     end
#     
#     it "should set the Client Identifier of the packet correctly" do
#       @packet.keep_alive.should == 10
#     end
#   end

end

describe MQTT::Packet::Connack do
  describe "when serialising a packet" do
    it "should output the correct bytes for a sucessful connection acknowledgement packet" do
      packet = MQTT::Packet::Connack.new( :return_code => 0x00 )
      packet.to_s.should == "\x20\x02\x00\x00"
    end
    
    it "should throw an exception when there is no client identifier" do
      lambda { MQTT::Packet::Connect.new.to_s }.should raise_error
    end
  end
  
  describe "when reading and deserialising a successful Connection Accepted packet from a socket" do
    before(:each) do
      @io = StringIO.new("\x20\x02\x00\x00")
      @packet = MQTT::Packet.read( @io )
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
  
  describe "when reading and deserialising a unacceptable protocol version packet from a socket" do
    before(:each) do
      @io = StringIO.new("\x20\x02\x00\x01")
      @packet = MQTT::Packet.read( @io )
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
  
  describe "when reading and deserialising a client identifier rejected packet from a socket" do
    before(:each) do
      @io = StringIO.new("\x20\x02\x00\x02")
      @packet = MQTT::Packet.read( @io )
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
  
  describe "when reading and deserialising a broker unavailable packet from a socket" do
    before(:each) do
      @io = StringIO.new("\x20\x02\x00\x03")
      @packet = MQTT::Packet.read( @io )
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
  
  describe "when reading and deserialising an unknown connection refused packet from a socket" do
    before(:each) do
      @io = StringIO.new("\x20\x02\x00\x04")
      @packet = MQTT::Packet.read( @io )
    end
    
    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Connack
    end
    
    it "should set the return code of the packet correctly" do
      @packet.return_code.should == 0x04
    end
    
    it "should set the return message of the packet correctly" do
      @packet.return_msg.should match(/Connection refused: error code 4/i)
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
  
  describe "when reading and deserialising a packet from a socket" do
    before(:each) do
      @io = StringIO.new("\x40\x02\x12\x34")
      @packet = MQTT::Packet.read( @io )
    end
    
    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Puback
    end
    
    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
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
  
  describe "when reading and deserialising a packet from a socket" do
    before(:each) do
      @io = StringIO.new("\x50\x02\x12\x34")
      @packet = MQTT::Packet.read( @io )
    end
    
    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Pubrec
    end
    
    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
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
  
  describe "when reading and deserialising a packet from a socket" do
    before(:each) do
      @io = StringIO.new("\x60\x02\x12\x34")
      @packet = MQTT::Packet.read( @io )
    end
    
    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Pubrel
    end
    
    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
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
  
  describe "when reading and deserialising a packet from a socket" do
    before(:each) do
      @io = StringIO.new("\x70\x02\x12\x34")
      @packet = MQTT::Packet.read( @io )
    end
    
    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Pubcomp
    end
    
    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
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
      lambda { MQTT::Packet::Subscribe.new.to_s }.should raise_error
    end
  end
  
  describe "when reading and deserialising a packet with a single topic from a socket" do
    before(:each) do
      @io = StringIO.new("\x82\x08\x00\x01\x00\x03a/b\x00")
      @packet = MQTT::Packet.read( @io )
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
  
  describe "when reading and deserialising a packet with a two topics from a socket" do
    before(:each) do
      @io = StringIO.new("\x82\x0e\000\x06\x00\x03a/b\x00\x00\x03c/d\x01")
      @packet = MQTT::Packet.read( @io )
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
      packet = MQTT::Packet::Suback.new( :granted_qos => [0,1], :message_id => 5 )
      packet.to_s.should == "\x90\x04\x00\x05\x00\x01"
    end

    it "should output the correct bytes for an acknowledgement to a two topics" do
      packet = MQTT::Packet::Suback.new( :granted_qos => [[0,0],[1,0]], :message_id => 6 )
      packet.to_s.should == "\x90\x06\x00\x06\x00\x00\x01\x00"
    end
    
    it "should throw an exception when no granted QOSs are given" do
      lambda { MQTT::Packet::Unsubscribe.new.to_s }.should raise_error
    end
  end
  
  describe "when reading and deserialising a packet from a socket" do
    before(:each) do
      @io = StringIO.new("\x90\x04\x12\x34\x01\x01")
      @packet = MQTT::Packet.read( @io )
    end
    
    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Suback
    end
    
    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
    end
    
    it "should set the Granted QOS of the packet correctly" do
      @packet.granted_qos.should == [[1,1]]
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
      lambda { MQTT::Packet::Unsubscribe.new.to_s }.should raise_error
    end
  end
  
  describe "when reading and deserialising a packet from a socket" do
    before(:each) do
      @io = StringIO.new("\xa2\f\000\005\000\003a/b\000\003c/d")
      @packet = MQTT::Packet.read( @io )
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
  
  describe "when reading and deserialising a packet from a socket" do
    before(:each) do
      @io = StringIO.new("\xB0\x02\x12\x34")
      @packet = MQTT::Packet.read( @io )
    end
    
    it "should correctly create the right type of packet object" do
      @packet.class.should == MQTT::Packet::Unsuback
    end
    
    it "should set the message id of the packet correctly" do
      @packet.message_id.should == 0x1234
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
  
  describe "when reading and deserialising a packet from a socket" do
    it "should correctly create the right type of packet object" do
      io = StringIO.new("\xC0\x00")
      packet = MQTT::Packet.read( io )
      packet.class.should == MQTT::Packet::Pingreq
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
  
  describe "when reading and deserialising a packet from a socket" do
    it "should correctly create the right type of packet object" do
      io = StringIO.new("\xD0\x00")
      packet = MQTT::Packet.read( io )
      packet.class.should == MQTT::Packet::Pingresp
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
  
  describe "when reading and deserialising a packet from a socket" do
    it "should correctly create the right type of packet object" do
      io = StringIO.new("\xE0\x00")
      packet = MQTT::Packet.read( io )
      packet.class.should == MQTT::Packet::Disconnect
    end
    
    it "should throw an exception if the packet has a payload" do
      io = StringIO.new("\xE0\x05hello")
      lambda { MQTT::Packet.read( io ) }.should raise_error
    end
  end
end

