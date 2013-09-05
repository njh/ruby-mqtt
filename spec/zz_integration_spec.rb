 $:.unshift(File.dirname(__FILE__))

require 'spec_helper'
require 'mqtt'
require 'fake_server'

describe "a client talking to a server" do

  before(:each) do
    @error_log = StringIO.new
    @server = MQTT::FakeServer.new
    @server.just_one = true
    @server.logger = Logger.new(@error_log)
    @server.logger.level = Logger::WARN
    @server.start

    @client = MQTT::Client.new(@server.address, @server.port)
  end

  after(:each) do
    @client.disconnect
    @server.stop
  end

  context "connecting and publishing a packet" do
    def connect_and_publish
      @client.connect
      @client.publish('test', 'foobar')
      @server.thread.join(1)
    end
    
    it "the server should not report any errors" do
      connect_and_publish
      @error_log.string.should be_empty
    end

    it "the server should have received a packet" do
      connect_and_publish
      @server.last_publish.should_not be_nil
    end

    it "the server should have received the correct topic" do
      connect_and_publish
      @server.last_publish.topic.should == 'test'
    end

    it "the server should have received the correct payload" do
      connect_and_publish
      @server.last_publish.payload.should == 'foobar'
    end
  end

end
