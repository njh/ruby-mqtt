$:.unshift(File.dirname(__FILE__))

require 'spec_helper'

describe MQTT::SN::Packet do

  describe "when creating a new packet" do
    it "should allow you to set the packet dup flag as a hash parameter" do
      packet = MQTT::SN::Packet.new(:duplicate => true)
      expect(packet.duplicate).to be_truthy
    end

    it "should allow you to set the packet QOS level as a hash parameter" do
      packet = MQTT::SN::Packet.new(:qos => 2)
      expect(packet.qos).to eq(2)
    end

    it "should allow you to set the packet retain flag as a hash parameter" do
      packet = MQTT::SN::Packet.new(:retain => true)
      expect(packet.retain).to be_truthy
    end
  end

  describe "getting the type id on a un-subclassed packet" do
    it "should throw an exception" do
      expect {
        MQTT::SN::Packet.new.type_id
      }.to raise_error(
        RuntimeError,
        "Invalid packet type: MQTT::SN::Packet"
      )
    end
  end

  describe "Parsing a packet that does not match the packet length" do
    it "should throw an exception" do
      expect {
        packet = MQTT::SN::Packet.parse("\x02\x1834567")
      }.to raise_error(
        MQTT::SN::ProtocolException,
        "Length of packet is not the same as the length header"
      )
    end
  end

end


describe MQTT::SN::Packet::Connect do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Connect.new
    expect(packet.type_id).to eq(0x04)
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a packet with no flags" do
      packet = MQTT::SN::Packet::Connect.new(
        :client_id => 'mqtt-sn-client-pub'
      )
      expect(packet.to_s).to eq("\x18\x04\x04\x01\x00\x0fmqtt-sn-client-pub")
    end

    it "should output the correct bytes for a packet with clean session turned off" do
      packet = MQTT::SN::Packet::Connect.new(
        :client_id => 'myclient',
        :clean_session => false
      )
      expect(packet.to_s).to eq("\016\004\000\001\000\017myclient")
    end

    it "should throw an exception when there is no client identifier" do
      expect {
        MQTT::SN::Packet::Connect.new.to_s
      }.to raise_error(
        'Invalid client identifier when serialising packet'
      )
    end

    it "should output the correct bytes for a packet with a will request" do
      packet = MQTT::SN::Packet::Connect.new(
        :client_id => 'myclient',
        :request_will => true,
        :clean_session => true
      )
      expect(packet.to_s).to eq("\016\004\014\001\000\017myclient")
    end

    it "should output the correct bytes for with a custom keep alive" do
      packet = MQTT::SN::Packet::Connect.new(
        :client_id => 'myclient',
        :request_will => true,
        :clean_session => true,
        :keep_alive => 30
      )
      expect(packet.to_s).to eq("\016\004\014\001\000\036myclient")
    end
  end

  describe "when parsing a simple Connect packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x18\x04\x04\x01\x00\x00mqtt-sn-client-pub") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Connect)
    end

    it "should not have the request will flag set" do
      expect(packet.request_will).to be_falsy
    end

    it "shoul have the clean session flag set" do
      expect(packet.clean_session).to be_truthy
    end

    it "should set the Keep Alive timer of the packet correctly" do
      expect(packet.keep_alive).to eq(0)
    end

    it "should set the Client Identifier of the packet correctly" do
      expect(packet.client_id).to eq('mqtt-sn-client-pub')
    end
  end

  describe "when parsing a Connect packet with the clean session flag set" do
    let(:packet) { MQTT::SN::Packet.parse("\016\004\004\001\000\017myclient") }

    it "should set the clean session flag" do
      expect(packet.clean_session).to be_truthy
    end
  end

  describe "when parsing a Connect packet with the will request flag set" do
    let(:packet) { MQTT::SN::Packet.parse("\016\004\014\001\000\017myclient") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Connect)
    end
    it "should set the Client Identifier of the packet correctly" do
      expect(packet.client_id).to eq('myclient')
    end

    it "should set the clean session flag should be set" do
      expect(packet.clean_session).to be_truthy
    end

    it "should set the Will retain flag should be false" do
      expect(packet.request_will).to be_truthy
    end
  end

  context "that has an invalid type identifier" do
    it "should throw an exception" do
      expect {
        MQTT::SN::Packet.parse("\x02\xFF")
      }.to raise_error(
        MQTT::SN::ProtocolException,
        "Invalid packet type identifier: 255"
      )
    end
  end

  describe "when parsing a Connect packet an unsupport protocol ID" do
    it "should throw an exception" do
      expect {
        packet = MQTT::SN::Packet.parse(
          "\016\004\014\005\000\017myclient"
        )
      }.to raise_error(
        MQTT::SN::ProtocolException,
        "Unsupported protocol ID number: 5"
      )
    end
  end
end

describe MQTT::SN::Packet::Connack do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Connack.new
    expect(packet.type_id).to eq(0x05)
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a sucessful connection acknowledgement packet" do
      packet = MQTT::SN::Packet::Connack.new(:return_code => 0x00)
      expect(packet.to_s).to eq("\x03\x05\x00")
    end
  end

  describe "when parsing a successful Connection Accepted packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x03\x05\x00") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Connack)
    end

    it "should set the return code of the packet correctly" do
      expect(packet.return_code).to eq(0x00)
    end

    it "should set the return message of the packet correctly" do
      expect(packet.return_msg).to match(/accepted/i)
    end
  end

  describe "when parsing a congestion packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x03\x05\x01") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Connack)
    end

    it "should set the return code of the packet correctly" do
      expect(packet.return_code).to eq(0x01)
    end

    it "should set the return message of the packet correctly" do
      expect(packet.return_msg).to match(/rejected: congestion/i)
    end
  end

  describe "when parsing a invalid topic ID packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x03\x05\x02") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Connack)
    end

    it "should set the return code of the packet correctly" do
      expect(packet.return_code).to eq(0x02)
    end

    it "should set the return message of the packet correctly" do
      expect(packet.return_msg).to match(/rejected: invalid topic ID/i)
    end
  end

  describe "when parsing a 'not supported' packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x03\x05\x03") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Connack)
    end

    it "should set the return code of the packet correctly" do
      expect(packet.return_code).to eq(0x03)
    end

    it "should set the return message of the packet correctly" do
      expect(packet.return_msg).to match(/not supported/i)
    end
  end

  describe "when parsing an unknown connection refused packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x03\x05\x10") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Connack)
    end

    it "should set the return code of the packet correctly" do
      expect(packet.return_code).to eq(0x10)
    end

    it "should set the return message of the packet correctly" do
      expect(packet.return_msg).to match(/rejected/i)
    end
  end
end


describe MQTT::SN::Packet::Register do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Register.new
    expect(packet.type_id).to eq(0x0A)
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a register packet" do
      packet = MQTT::SN::Packet::Register.new(
        :id => 0x01,
        :topic_id => 0x01,
        :topic_name => 'test'
      )
      expect(packet.to_s).to eq("\x0A\x0A\x00\x01\x00\x01test")
    end
  end

  describe "when parsing a Register packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x0A\x0A\x00\x01\x00\x01test") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Register)
    end

    it "should set the topic id type of the packet correctly" do
      expect(packet.topic_id_type).to eq(:normal)
    end

    it "should set the topic id of the packet correctly" do
      expect(packet.topic_id).to eq(0x01)
    end

    it "should set the message id of the packet correctly" do
      expect(packet.id).to eq(0x01)
    end

    it "should set the topic name of the packet correctly" do
      expect(packet.topic_name).to eq('test')
    end
  end
end


describe MQTT::SN::Packet::Regack do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Regack.new
    expect(packet.type_id).to eq(0x0B)
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a register packet" do
      packet = MQTT::SN::Packet::Regack.new(
        :id => 0x02,
        :topic_id => 0x01,
        :return_code => 0x03
      )
      expect(packet.to_s).to eq("\x07\x0B\x00\x01\x00\x02\x03")
    end
  end

  describe "when parsing a REGACK packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x07\x0B\x00\x01\x00\x02\x03") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Regack)
    end

    it "should set the topic id type of the packet correctly" do
      expect(packet.topic_id_type).to eq(:normal)
    end

    it "should set the topic id of the packet correctly" do
      expect(packet.topic_id).to eq(0x01)
    end

    it "should set the message id of the packet correctly" do
      expect(packet.id).to eq(0x02)
    end

    it "should set the topic name of the packet correctly" do
      expect(packet.return_code).to eq(0x03)
    end
  end
end


describe MQTT::SN::Packet::Publish do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Publish.new
    expect(packet.type_id).to eq(0x0C)
  end

  describe "when serialising a packet with a normal topic id type" do
    it "should output the correct bytes for a publish packet" do
      packet = MQTT::SN::Packet::Publish.new(
        :topic_id => 0x01,
        :topic_id_type => :normal,
        :data => "Hello World"
      )
      expect(packet.to_s).to eq("\x12\x0C\x00\x00\x01\x00\x00Hello World")
    end
  end

  describe "when serialising a packet with a short topic id type" do
    it "should output the correct bytes for a publish packet of QoS -1" do
      packet = MQTT::SN::Packet::Publish.new(
        :qos => -1,
        :topic_id => 'tt',
        :topic_id_type => :short,
        :data => "Hello World"
      )
      expect(packet.to_s).to eq("\x12\x0C\x62tt\x00\x00Hello World")
    end

    it "should output the correct bytes for a publish packet of QoS 0" do
      packet = MQTT::SN::Packet::Publish.new(
        :qos => 0,
        :topic_id => 'tt',
        :topic_id_type => :short,
        :data => "Hello World"
      )
      expect(packet.to_s).to eq("\x12\x0C\x02tt\x00\x00Hello World")
    end

    it "should output the correct bytes for a publish packet of QoS 1" do
      packet = MQTT::SN::Packet::Publish.new(
        :qos => 1,
        :topic_id => 'tt',
        :topic_id_type => :short,
        :data => "Hello World"
      )
      expect(packet.to_s).to eq("\x12\x0C\x22tt\x00\x00Hello World")
    end

    it "should output the correct bytes for a publish packet of QoS 2" do
      packet = MQTT::SN::Packet::Publish.new(
        :qos => 2,
        :topic_id => 'tt',
        :topic_id_type => :short,
        :data => "Hello World"
      )
      expect(packet.to_s).to eq("\x12\x0C\x42tt\x00\x00Hello World")
    end
  end

  describe "when serialising a packet with a pre-defined topic id type" do
    it "should output the correct bytes for a publish packet" do
      packet = MQTT::SN::Packet::Publish.new(
        :topic_id => 0x00EE,
        :topic_id_type => :predefined,
        :data => "Hello World"
      )
      expect(packet.to_s).to eq("\x12\x0C\x01\x00\xEE\x00\x00Hello World")
    end
  end

  describe "when serialising packet larger than 256 bytes" do
    let(:packet) {
      MQTT::SN::Packet::Publish.new(
        :topic_id => 0x10,
        :topic_id_type => :normal,
        :data => "Hello World" * 100
      )
    }

    it "should have the first byte set to 1" do
      expect(packet.to_s[0]).to eq("\x01")
    end

    it "should have the second and third bytes set to 0x0455" do
      expect(packet.to_s[1,2]).to eq("\x04\x55")
    end

    it "should have a total length of 0x0455 (1109) bytes" do
      expect(packet.to_s.length).to eq(0x0455)
    end
  end

  describe "when serialising an excessively large packet" do
    it "should throw an exception" do
      expect {
        MQTT::SN::Packet::Publish.new(
          :topic_id => 0x01,
          :topic_id_type => :normal,
          :data => "Hello World" * 6553
        ).to_s
      }.to raise_error(
        RuntimeError,
        "MQTT-SN Packet is too big, maximum packet body size is 65531"
      )
    end
  end

  describe "when parsing a Publish packet with a normal topic id" do
    let(:packet) { MQTT::SN::Packet.parse("\x12\x0C\x00\x00\x01\x00\x00Hello World") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Publish)
    end

    it "should set the QOS of the packet correctly" do
      expect(packet.qos).to be === 0
    end

    it "should set the QOS of the packet correctly" do
      expect(packet.duplicate).to be === false
    end

    it "should set the retain flag of the packet correctly" do
      expect(packet.retain).to be === false
    end

    it "should set the topic id of the packet correctly" do
      expect(packet.topic_id_type).to be === :normal
    end

    it "should set the topic id of the packet correctly" do
      expect(packet.topic_id).to be === 0x01
    end

    it "should set the message id of the packet correctly" do
      expect(packet.id).to be === 0x0000
    end

    it "should set the topic name of the packet correctly" do
      expect(packet.data).to eq("Hello World")
    end
  end

  describe "when parsing a Publish packet with a short topic id" do
    let(:packet) { MQTT::SN::Packet.parse("\x12\x0C\x02tt\x00\x00Hello World") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Publish)
    end

    it "should set the QOS of the packet correctly" do
      expect(packet.qos).to be === 0
    end

    it "should set the QOS of the packet correctly" do
      expect(packet.duplicate).to be === false
    end

    it "should set the retain flag of the packet correctly" do
      expect(packet.retain).to be === false
    end

    it "should set the topic id type of the packet correctly" do
      expect(packet.topic_id_type).to be === :short
    end

    it "should set the topic id of the packet correctly" do
      expect(packet.topic_id).to be === 'tt'
    end

    it "should set the message id of the packet correctly" do
      expect(packet.id).to be === 0x0000
    end

    it "should set the topic name of the packet correctly" do
      expect(packet.data).to eq("Hello World")
    end
  end

  describe "when parsing a Publish packet with a short topic id and QoS -1" do
    let(:packet) { MQTT::SN::Packet.parse("\x12\x0C\x62tt\x00\x00Hello World") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Publish)
    end

    it "should set the QOS of the packet correctly" do
      expect(packet.qos).to be === -1
    end

    it "should set the QOS of the packet correctly" do
      expect(packet.duplicate).to be === false
    end

    it "should set the retain flag of the packet correctly" do
      expect(packet.retain).to be === false
    end

    it "should set the topic id type of the packet correctly" do
      expect(packet.topic_id_type).to be === :short
    end

    it "should set the topic id of the packet correctly" do
      expect(packet.topic_id).to be === 'tt'
    end

    it "should set the message id of the packet correctly" do
      expect(packet.id).to be === 0x0000
    end

    it "should set the topic name of the packet correctly" do
      expect(packet.data).to eq("Hello World")
    end
  end

  describe "when parsing a Publish packet with a predefined topic id type" do
    let(:packet) { MQTT::SN::Packet.parse("\x12\x0C\x01\x00\xEE\x00\x00Hello World") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Publish)
    end

    it "should set the topic id type of the packet correctly" do
      expect(packet.topic_id_type).to eql(:predefined)
    end

    it "should set the topic id of the packet correctly" do
      expect(packet.topic_id).to eq(0xEE)
    end
  end

  describe "when parsing a Publish packet with a invalid topic id type" do
    let(:packet) { MQTT::SN::Packet.parse("\x12\x0C\x03\x00\x10\x55\xCCHello World") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Publish)
    end

    it "should set the QOS of the packet correctly" do
      expect(packet.qos).to be === 0
    end

    it "should set the QOS of the packet correctly" do
      expect(packet.duplicate).to be === false
    end

    it "should set the retain flag of the packet correctly" do
      expect(packet.retain).to be === false
    end

    it "should set the topic id type of the packet correctly" do
      expect(packet.topic_id_type).to be_nil
    end

    it "should set the topic id of the packet correctly" do
      expect(packet.topic_id).to eq(0x10)
    end

    it "should set the message id of the packet correctly" do
      expect(packet.id).to be === 0x55CC
    end

    it "should set the topic name of the packet correctly" do
      expect(packet.data).to eq("Hello World")
    end
  end

  describe "when parsing a Publish packet longer than 256 bytes" do
    let(:packet) { MQTT::SN::Packet.parse("\x01\x04\x55\x0C\x62tt\x00\x00" + ("Hello World" * 100)) }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Publish)
    end

    it "should set the QOS of the packet correctly" do
      expect(packet.qos).to be === -1
    end

    it "should set the QOS of the packet correctly" do
      expect(packet.duplicate).to be === false
    end

    it "should set the retain flag of the packet correctly" do
      expect(packet.retain).to be === false
    end

    it "should set the topic id type of the packet correctly" do
      expect(packet.topic_id_type).to be === :short
    end

    it "should set the topic id of the packet correctly" do
      expect(packet.topic_id).to be === 'tt'
    end

    it "should set the message id of the packet correctly" do
      expect(packet.id).to be === 0x0000
    end

    it "should set the topic name of the packet correctly" do
      expect(packet.data).to eq("Hello World" * 100)
    end
  end
end


describe MQTT::SN::Packet::Subscribe do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Subscribe.new
    expect(packet.type_id).to eq(0x12)
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a Subscribe packet" do
      packet = MQTT::SN::Packet::Subscribe.new(
        :duplicate => false,
        :qos => 0,
        :id => 0x02,
        :topic_name => 'test'
      )
      expect(packet.to_s).to eq("\x09\x12\x00\x00\x02test")
    end
  end

  describe "when parsing a Subscribe packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x09\x12\x00\x00\x03test") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Subscribe)
    end

    it "should set the message id of the packet correctly" do
      expect(packet.id).to eq(0x03)
    end

    it "should set the message id of the packet correctly" do
      expect(packet.qos).to eq(0)
    end

    it "should set the message id of the packet correctly" do
      expect(packet.duplicate).to eq(false)
    end

    it "should set the topic name of the packet correctly" do
      expect(packet.topic_name).to eq('test')
    end
  end
end


describe MQTT::SN::Packet::Suback do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Suback.new
    expect(packet.type_id).to eq(0x13)
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a register packet" do
      packet = MQTT::SN::Packet::Suback.new(
        :id => 0x02,
        :qos => 0,
        :topic_id => 0x01,
        :return_code => 0x03
      )
      expect(packet.to_s).to eq("\x08\x13\x00\x00\x01\x00\x02\x03")
    end
  end

  describe "when parsing a SUBACK packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x08\x13\x00\x00\x01\x00\x02\x03") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Suback)
    end

    it "should set the topic id of the packet correctly" do
      expect(packet.qos).to eq(0)
    end

    it "should set the topic id type of the packet correctly" do
      expect(packet.topic_id_type).to eq(:normal)
    end

    it "should set the topic id of the packet correctly" do
      expect(packet.topic_id).to eq(0x01)
    end

    it "should set the message id of the packet correctly" do
      expect(packet.id).to eq(0x02)
    end

    it "should set the topic name of the packet correctly" do
      expect(packet.return_code).to eq(0x03)
    end
  end
end


describe MQTT::SN::Packet::Unsubscribe do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Unsubscribe.new
    expect(packet.type_id).to eq(0x14)
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a Unsubscribe packet" do
      packet = MQTT::SN::Packet::Unsubscribe.new(
        :id => 0x02,
        :duplicate => false,
        :qos => 0,
        :topic_name => 'test'
      )
      expect(packet.to_s).to eq("\x09\x14\x00\x00\x02test")
    end
  end

  describe "when parsing a Unsubscribe packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x09\x14\x00\x00\x03test") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Unsubscribe)
    end

    it "should set the message id of the packet correctly" do
      expect(packet.id).to eq(0x03)
    end

    it "should set the message id of the packet correctly" do
      expect(packet.qos).to eq(0)
    end

    it "should set the message id of the packet correctly" do
      expect(packet.duplicate).to eq(false)
    end

    it "should set the topic name of the packet correctly" do
      expect(packet.topic_name).to eq('test')
    end
  end
end


describe MQTT::SN::Packet::Unsuback do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Unsuback.new
    expect(packet.type_id).to eq(0x15)
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a register packet" do
      packet = MQTT::SN::Packet::Unsuback.new(:id => 0x02)
      expect(packet.to_s).to eq("\x04\x15\x00\x02")
    end
  end

  describe "when parsing a SUBACK packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x04\x15\x00\x02") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Unsuback)
    end

    it "should set the message id of the packet correctly" do
      expect(packet.id).to eq(0x02)
    end
  end
end


describe MQTT::SN::Packet::Pingreq do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Pingreq.new
    expect(packet.type_id).to eq(0x16)
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a pingreq packet" do
      packet = MQTT::SN::Packet::Pingreq.new
      expect(packet.to_s).to eq("\x02\x16")
    end
  end

  describe "when parsing a Pingreq packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x02\x16") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Pingreq)
    end
  end
end


describe MQTT::SN::Packet::Pingresp do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Pingresp.new
    expect(packet.type_id).to eq(0x17)
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a pingresp packet" do
      packet = MQTT::SN::Packet::Pingresp.new
      expect(packet.to_s).to eq("\x02\x17")
    end
  end

  describe "when parsing a Pingresp packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x02\x17") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Pingresp)
    end
  end
end


describe MQTT::SN::Packet::Disconnect do
  it "should have the right type id" do
    packet = MQTT::SN::Packet::Disconnect.new
    expect(packet.type_id).to eq(0x18)
  end

  describe "when serialising a packet" do
    it "should output the correct bytes for a disconnect packet" do
      packet = MQTT::SN::Packet::Disconnect.new
      expect(packet.to_s).to eq("\x02\x18")
    end
  end

  describe "when parsing a Disconnect packet" do
    let(:packet) { MQTT::SN::Packet.parse("\x02\x18") }

    it "should correctly create the right type of packet object" do
      expect(packet.class).to eq(MQTT::SN::Packet::Disconnect)
    end
  end
end
