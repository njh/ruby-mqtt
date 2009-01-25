$:.unshift(File.dirname(__FILE__))

require 'spec_helper'
require 'mqtt/packet'

describe MQTT::Packet do

  describe "when creating a new packet" do
    it "should allow you to set the packet type as a hash parameter" do
      packet = MQTT::Packet.new( :type => :connect )
      packet.type.should == :connect
    end
  
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
  
    it "should allow you to set the packet body as a hash parameter" do
      packet = MQTT::Packet.new( :body => 'Hello World' )
      packet.body.should == 'Hello World'
    end
  end   
  
  describe "when setting packet parameters" do
    before(:each) do
      @packet = MQTT::Packet.new(
        :type => nil,
        :dup => false,
        :qos => 0,
        :retain => false,
        :body => 'test'
      )
    end
    
    it "should let you change the type of a packet" do
      @packet.type = :pingreq
      @packet.type.should == :pingreq
    end
    
    it "should let you set the packet type based on its integer id" do
      @packet.type = 10
      @packet.type.should == :unsubscribe
    end
    
    it "should have a type_id method to get the integer ID of the packet type" do
      @packet.type = :pingreq
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
    
    it "should let you change the body of a packet" do
      @packet.body = 'test2'
      @packet.body.should == 'test2'
    end
    
    it "should convert the body to a string" do
      @packet.body = :ratrat
      @packet.body.should == 'ratrat'
    end
  end
  
  
  describe "when adding data to the packet's body" do
    before(:each) do
      @packet = MQTT::Packet.new( :body => '' )
    end

    it "should provide a add_bytes method to add some bytes as Integers" do
      @packet.add_bytes(0x48, 0x65, 0x6c, 0x6c, ?o)
      @packet.body.should == 'Hello'
    end

    it "should provide a add_short method to add a big-endian unsigned 16-bit integer" do
      @packet.add_short(1024)
      @packet.body.should == "\x04\x00"
    end

    it "should provide a add_data method to add raw data" do
      @packet.add_data('quack')
      @packet.body.should == "quack"
    end

    it "should provide a add_string method to add a string preceeded by its length" do
      @packet.add_string('quack')
      @packet.body.should == "\x00\x05quack"
    end
  end
  
  
  describe "when extracting data to the packet's body" do
    it "should provide a shift_short method to get a 16-bit unsigned integer" do
      packet = MQTT::Packet.new( :body => "\x22\x8Bblahblahblah" )
      packet.shift_short.should == 8843
    end

    it "should provide a shift_bytes method to get N bytes as integers" do
      packet = MQTT::Packet.new( :body => "\x01\x02\x03\x04\xFF\x05\x06" )
      packet.shift_bytes(5).should == [1,2,3,4,255]
    end

    it "should provide a shift_data method to get N raw bytes" do
      packet = MQTT::Packet.new( :body => "Hello World" )
      packet.shift_data(5).should == 'Hello'
    end

    it "should provide a shift_string method to get a string preceeded by its length" do
      packet = MQTT::Packet.new( :body => "\x00\x05Hello World" )
      packet.shift_string.should == 'Hello'
    end
  end
  
  
  describe "when serialising a packet" do
    it "should output the correct bytes for a basic ping packet with no flags and no body" do
      packet = MQTT::Packet.new(:type => :pingreq)
      packet.to_s.should == "\xC0\x00"
    end
  
    it "should output the correct bytes for a message with a body and no flags" do
      packet = MQTT::Packet.new(:type => :connack)
      packet.add_bytes(0x00, 0x00)
      packet.to_s.should == "\x20\x02\x00\x00"
    end
  
    it "should output the correct bytes for a message with a qos set to 1" do
      packet = MQTT::Packet.new(:type => :publish, :qos => 1)
      packet.add_string('a/b')
      packet.add_short(10)
      packet.add_data('message')
      packet.to_s.should ==
        "\x32\x0e" + # fixed header 0x32 = 0b00110010
        "\x00\x03a/b" + # topic
        "\x00\x0A" + # message id
        "message" # payload
    end
  
    it "should output the correct bytes for a message with a qos set to 2 and retain and dup flags set" do
      # This isn't really a valid MQTT packet, but it tests packet serialisation
      packet = MQTT::Packet.new(:type => :disconnect, :qos => 2, :retain => true, :dup => true)
      packet.add_short(10)
      packet.to_s.should ==
        "\xed\x02" + # fixed header 0xed = 0b11101101
        "\x00\x0A"   # message id
    end
  end
  
  it "should have a custom inspector that does not output the packet body" do
    packet = MQTT::Packet.new(:type => :pingreq)
    packet.inspect.should match(/^#<MQTT::Packet:0x([0-9a-f]+) type=pingreq, dup=false, retain=false, qos=0, body.size=0>$/)
  end
  
  describe "when reading and deserialising a packet from a socket" do
    
    describe "a packet with no flags or body" do
      before(:each) do
        @io = StringIO.new("\xC0\x00")
        @packet = MQTT::Packet.read( @io )
      end
      
      it "should have reached the end of the input" do
        @io.should be_eof
      end
     
      it "should parse the packet type correctly" do
        @packet.type.should == :pingreq
      end
      
      it "should parse the QOS level correctly" do
        @packet.qos.should == 0
      end
      
      it "should parse the dup flag correctly" do
        @packet.dup.should == false
      end
      
      it "should parse the retain flag correctly" do
        @packet.retain.should == false
      end
      
      it "should have an empty body" do
        @packet.body.should == ''
      end
    end
    
    describe "a packet with all flag set and a short body" do
      before(:each) do
        @io = StringIO.new("\xed\x02\x00\x0A")
        @packet = MQTT::Packet.read( @io )
      end
       
      it "should have reached the end of the input" do
        @io.should be_eof
      end
     
      it "should parse the packet type correctly" do
        @packet.type.should == :disconnect
      end
      
      it "should parse the QOS level correctly" do
        @packet.qos.should == 2
      end
      
      it "should parse the dup flag correctly" do
        @packet.dup.should == true
      end
      
      it "should parse the retain flag correctly" do
        @packet.retain.should == true
      end
      
      it "should have a 2 byte body" do
        @packet.body.size.should == 2
      end
      
      it "should correctly decode the body as being an integer" do
        @packet.shift_short == 10
      end
    end

  end
  
end
