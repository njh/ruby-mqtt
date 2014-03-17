#!/usr/bin/env ruby
# encoding: utf-8
#
# Testsuite for 3.1.1 MQTT spec.
#
# Designed to be tested agains an eclipse Python MQTT 3.1.1 Broker
# git://git.eclipse.org/gitroot/paho/org.eclipse.paho.mqtt.testing.git

$:.unshift(File.dirname(__FILE__))

require 'bundler'
Bundler.require(:default, :development)
require 'mqtt'

# MQTT_HOST = 'localhost'
MQTT_HOST = ENV['MQTT_HOST'] || 'localhost'
MQTT_PORT = ENV['MQTT_PORT'] || 1883
MQTT_USERNAME = ENV['MQTT_USERNAME']
MQTT_PASSWORD = ENV['MQTT_PASSWORD']

def get_base_connection_map()
  base_map = {
    :remote_host => MQTT_HOST,
    :remote_port => MQTT_PORT,
    :v311 => true,
    :clean_session => true,
    :reconnect => false
  }

  if MQTT_PASSWORD.nil? == false and MQTT_USERNAME.nil? == false
    base_map[:username] = MQTT_USERNAME
    base_map[:password] = MQTT_PASSWORD
  end

  return base_map
end

def create_standard_client(&block)
  if block_given?
    MQTT::Client.connect(get_base_connection_map()) do |client|
      yield(client)
      sleep 0.25
    end
  else
    client = MQTT::Client.connect(get_base_connection_map())
    return client
  end
end

def create_unclean_client(client_id='ruby_client',&block)
  if block_given?
    MQTT::Client.connect(get_base_connection_map().merge({:clean_session => false, :client_id => client_id})) do |client|
      yield(client)
      sleep 0.25
    end
  else
    client = MQTT::Client.connect(get_base_connection_map().merge({:clean_session => false, :client_id => client_id}))
    return client
  end
end

test_name = 'MQTT 3.1.1 spec against: %s:%s ' % [MQTT_HOST,MQTT_PORT]
if MQTT_USERNAME.nil? == false and MQTT_PASSWORD.nil? == false
  test_name += ' username=%s and password=%s' % [MQTT_USERNAME,MQTT_PASSWORD]
end
describe test_name do

  it 'Connection based on the 3.1.1 spec', :basic => true do
    create_standard_client() do |client|
      sleep 0.5
    end
  end

  it 'Connection with an empty client ID and clean_session = false' do
    MQTT::Client.connect(get_base_connection_map().merge({:clean_session => true,:client_id=>''})){sleep 0.5}
  end

  it 'Raise exception when connecting with an empty client ID and clean_session = true' do
    expect {
      MQTT::Client.connect(get_base_connection_map().merge({:clean_session => false,:client_id=>''}))
    }.to raise_error
  end

  it 'Connection with Will message', :basic => true do
    will_topic = '/will_topic/%d' % Time.now.to_i
    will_message = Time.now.to_i.to_s
    client1 = MQTT::Client.connect(get_base_connection_map().merge({:will_topic => will_topic,:will_payload => will_message,:will_qos=>1,:will_retain=>true}))
    client2 = MQTT::Client.connect(get_base_connection_map().merge({:will_topic => will_topic,:will_payload => will_message,:will_qos=>1,:will_retain=>false}))
    sleep 0.25
    client1.disconnect(false)#Firing the will message
    client2.disconnect(false)#Firing the will message

    create_standard_client() do |client_sub|
      topic,message = client_sub.get(will_topic)
      message.should eq(will_message)
    end
  end

  it 'Connection with user and password' do
    username = MQTT_USERNAME || 'ruby_username'
    password = MQTT_PASSWORD || 'ruby_password'

    client1 = MQTT::Client.connect(get_base_connection_map().merge({:username=>username,:password=>password}))
    client2 = MQTT::Client.connect(get_base_connection_map().merge({:username=>username,:password=>password,:will_topic => 'msg2',:will_payload => 'A',:will_qos=>2,:will_retain=>false}))
    sleep 0.25
    client1.disconnect()
    client2.disconnect()
  end

  it 'Connection with Keep Alive aka Ping', :basic => true do
    client = MQTT::Client.connect(get_base_connection_map().merge({:keep_alive=>1}))
    sleep 2
    client.disconnect()
  end

  it 'Disconnect after not sending ping' do
    expect{
      client = MQTT::Client.connect(get_base_connection_map().merge({:keep_alive=>1}))
      client.keep_alive = 10
      sleep 10
      client.disconnect()
    }.to raise_error
  end

  it 'Subscription for QOS=0,1, and 2' do
    client = create_standard_client()

    client.subscribe(['msg0',0])
    client.subscribe(['msg1',1])
    client.subscribe(["msg2",2])
    sleep 0.5
    client.disconnect()
  end

  it '(Un)Subscription for multiple topics' do
    create_standard_client() do |client|
      client.subscribe(['msg3',2])
      client.unsubscribe('msg3')

      client.subscribe(['msg5',2],['msg6',1],['msg7',0])
      client.unsubscribe('msg5','msg6','msg7')
    end
  end

  it 'Unsubscribed for inexistent topic' do
    create_standard_client() do |client|
      client.unsubscribe('inexistent_topic')
    end
  end

  it 'Repeated Subscriptions' do
    create_standard_client() do |client|
      client.subscribe(['repeated_topic',0])
      client.subscribe(['repeated_topic',1])
      client.subscribe(['repeated_topic',2])
    end
  end

  it 'Subscribe and unsubscribe + Wildcard topics', :wildcard_test => true do
    client = create_standard_client()

    client.subscribe(['#',2])
    client.unsubscribe('#')

    client.subscribe(['+',2])
    client.unsubscribe('+')

    client.subscribe(['asd/+/#',2])
    client.unsubscribe('asd/+/#')

    client.disconnect()
  end

  it 'Publish an get messages with QOS=0,1, and 2',:basic => true do
    client_sub = create_unclean_client()
    client_pub = create_standard_client()

    client_sub.subscribe(['msg2',2],['msg1',1],['msg0',0])

    sleep 0.25
    client_pub.publish('msg2','msg',false,2)
    client_pub.publish('msg1','msg',false,1)
    client_pub.publish('msg0','msg',false,0)
    client_pub.publish('msg2','END',false,2)
    client_pub.disconnect()

    messages = []
    loop do
      topic,message = client_sub.get()

      #ap [topic,message]
      messages << message
      break if message == 'END'
    end
    messages.size.should be >= 4
    client_sub.disconnect()
  end

  it 'Publish an get messages with utf characters' do
    topic = 'utf_test_%d' % Time.now.to_i
    utf_message = "asdñ+çáü米"

    client_pub = create_standard_client()
    client_sub = create_unclean_client()

    client_sub.subscribe(topic)
    sleep 0.25
    client_pub.publish(topic,utf_message)

    topic,message = client_sub.get()

    message.should eq(utf_message)

    client_pub.disconnect()
    client_sub.disconnect()
  end

  it 'Queue messages while client is offline', :basic => true do
    random_topic = 'disconnected_topic_%d_' % Time.now.to_i

    client_sub = create_unclean_client('disconnected_client') do |client_sub|
      client_sub.subscribe([random_topic+'2',2],[random_topic+'1',1])
    end

    create_standard_client() do |client_pub|
      client_pub.publish(random_topic+'2','msg',false,2)
      client_pub.publish(random_topic+'1','msg',false,1)
    end

    create_unclean_client('disconnected_client') do |client_sub|
      messages = client_sub.get_batch_messages(nil,0.5,2)
      messages.size.should be(2)
    end
  end

  it 'Overlapping topics',:wildcard_test => true, :basic => true do
    topic = 'multiple/topic_%d' % Time.now.to_i
    message_sent = Time.now.to_i.to_s

    client_sub = create_standard_client()

    client_sub.subscribe(topic,'multiple/+')
    sleep 0.25

    create_standard_client() do |client_pub|
      client_pub.publish(topic,message_sent,false,1)
    end

    topic,message = client_sub.get()
    message.should eq(message_sent)

    client_sub.disconnect()
  end

  it 'Publish retained messages and receive them', :basic => true do
    retained_topic  = 'retained/%d' % Time.now.to_i
    retained_client = 'client_%d' % Time.now.to_i

    client_sub = create_unclean_client(retained_client)
    client_sub.subscribe(retained_topic)
    sleep 0.25
    client_sub.disconnect()

    client_pub = create_standard_client() do |client_pub|
      client_pub.publish(retained_topic,'retained_msg',true,0)
      client_pub.publish(retained_topic,'retained_msg',true,1)
      client_pub.publish(retained_topic,'retained_msg',true,2)
    end

    client_sub = create_unclean_client(retained_client)
    topic,message = client_sub.get(retained_topic)
    message.should eq('retained_msg')
    client_sub.disconnect()
  end

  it 'Unset retained messages', :basic => true do
    retained_topic = 'retained/%d' % Time.now.to_i

    create_standard_client() do |client_pub|
      client_pub.publish(retained_topic,'retained_msg',true,1)
      client_pub.publish(retained_topic,'',true,1)
    end

    create_standard_client() do |client_sub|
      messages = client_sub.get_batch_messages(retained_topic,0.5,1)
      messages.size.should be(0)
    end
  end

  it 'send messages with DUP=true for qos>0' do
    keep_alive = 2

    patched_client = MQTT::Client.connect(get_base_connection_map().merge({:keep_alive=>keep_alive}))
    def patched_client.receive_packet
      #'Monkey Patched'
      process_unreceived_acks()
      sleep 1
    end
    patched_client.publish('topic2','msg2',false,2)
    sleep 0.5
    patched_client.publish('topic1','msg1',false,1)
    sleep keep_alive * 1.5

    patched_client.disconnect(true,0.1)
  end

end
