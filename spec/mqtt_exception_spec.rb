$:.unshift(File.dirname(__FILE__))

require 'spec_helper'
require 'mqtt'

describe MQTT do

  describe "mqtt exceptions" do
    it "should be a ruby standard error" do
      expect(MQTT::ProtocolException.new).to be_a(StandardError)
      expect(MQTT::NotConnectedException.new).to be_a(StandardError)
      expect(MQTT::SN::ProtocolException.new).to be_a(StandardError)
    end

    it "should be an mqtt error" do
      expect(MQTT::ProtocolException.new).to be_a(MQTT::Exception)
      expect(MQTT::NotConnectedException.new).to be_a(MQTT::Exception)
      expect(MQTT::SN::ProtocolException.new).to be_a(MQTT::Exception)
    end
    
  end

end
