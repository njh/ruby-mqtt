#!/usr/bin/env ruby
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

def create_standard_client()
  client = MQTT::Client.connect(get_base_connection_map())
  return client
end

def create_unclean_client(client_id='ruby_client')
  client = MQTT::Client.connect(get_base_connection_map().merge({:clean_session => false, :client_id => client_id}))
  return client
end

test_name = 'MQTT 3.1.1 spec against: %s:%s ' % [MQTT_HOST,MQTT_PORT]
if MQTT_USERNAME.nil? == false and MQTT_PASSWORD.nil? == false
  test_name += ' username=%s and password=%s' % [MQTT_USERNAME,MQTT_PASSWORD]
end
describe test_name do

  it 'Connection with an empty client ID and clean_session = true' do
    begin
      client1 = MQTT::Client.connect(get_base_connection_map().merge({:clean_session => false,:client_id=>''})){}
    rescue Exception
    end
  end

  it 'Connection with an empty client ID and clean_session = false' do
    client2 = MQTT::Client.connect(get_base_connection_map().merge({:clean_session => true,:client_id=>''})){}
    client2.disconnect()
  end

  it 'Connection with Will Topic' do
    client3 = MQTT::Client.connect(get_base_connection_map().merge({:will_topic => 'msg1',:will_payload => 'A',:will_qos=>1,:will_retain=>true}))
    sleep 0.25
    client3.disconnect(false)

    sleep 0.25
    client4 = MQTT::Client.connect(get_base_connection_map().merge({:will_topic => 'msg2',:will_payload => 'A',:will_qos=>2,:will_retain=>false}))
    sleep 0.25
    client4.disconnect(false)
  end

  it 'Connection with user and password' do
    if MQTT_USERNAME.nil? and MQTT_PASSWORD.nil?
      client = MQTT::Client.connect(get_base_connection_map().merge({:username=>'ruby_client',:password=>'password'}))
      sleep 1
      client.disconnect()
    end
  end

  it 'Connection with Keep Alive aka Ping' do
    client = MQTT::Client.connect(get_base_connection_map().merge({:keep_alive=>2}))
    sleep 4
    client.disconnect()
  end

  it 'Subscription for QOS=0,1, and 2' do
    client = create_standard_client()

    client.subscribe(['msg0',0])
    client.subscribe(['msg1',1])
    client.subscribe(['msg2',2])

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
      client.subscribe('repeated_topic')
      client.subscribe('repeated_topic')
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

  it 'Publish an get messages with QOS=0,1, and 2' do
    client_sub = create_unclean_client()
    client_pub = create_standard_client()

    client_sub.subscribe(['msg2',2],['msg1',1],['msg0',0])

    sleep 0.5
    client_pub.publish('msg2','msg',false,2)
    sleep 0.5
    client_pub.publish('msg1','msg',false,1)
    sleep 0.5
    client_pub.publish('msg0','msg',false,0)
    sleep 0.5
    client_pub.publish('msg2','END',false,2)
    sleep 0.5
    client_pub.disconnect()

    loop do
      topic,message = client_sub.get()

      #ap [topic,message]
      break if message == 'END'
    end

    client_sub.disconnect()

  end

  it 'Receives messages while disconnected' do
    client_sub = create_unclean_client('disconnected_client')
    client_sub.subscribe(['disconnected2',2],['disconnected1',1],['disconnected0',0])
    client_sub.disconnect()

    client_pub = create_standard_client()

    client_pub.publish('disconnected2','msg1',false,2)
    client_pub.publish('disconnected1','msg2',false,1)
    client_pub.publish('disconnected2','msg3',false,2)
    client_pub.publish('disconnected1','msg4',false,1)

    client_pub.disconnect()

    client_sub = create_unclean_client('disconnected_client')
    messages = client_sub.get_batch_messages(nil,0.5,2)
    client_sub.disconnect()
  end

  it 'Overlapping topics',:wildcard_test => true do
    client_pub = create_standard_client()
    client_sub = create_standard_client()

    client_sub.subscribe('mutiple/topic_match','multiple/+')
    sleep 0.5
    client_pub.publish('mutiple/topic_match','msg1',false,2)
    client_pub.disconnect()

    messages = client_sub.get_batch_messages(nil,0.5,2)
    messages.size.should be(1)
    client_sub.disconnect()
  end

  it 'Publish retained messages and receive them' do
    retained_topic = 'retained/%d' % Time.now.to_i

    client_pub = create_standard_client()
    client_pub.publish(retained_topic,'retained_msg',true,2)
    client_pub.disconnect()

    client_sub = create_standard_client()
    messages = client_sub.get_batch_messages(retained_topic,0.5,2)
    messages.size.should be(1)
    client_sub.disconnect()
  end

  it 'Publish retained messages and clean them' do
    retained_topic = 'retained/%d' % Time.now.to_i

    client = create_standard_client()
    client.publish(retained_topic,'message',true,2)
    sleep 0.5
    client.publish(retained_topic,'',true,2)
    client.disconnect()
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