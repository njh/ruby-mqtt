$:.unshift(File.dirname(__FILE__))

require 'bundler'
Bundler.require(:default, :development)
require 'mqtt'

# MQTT_HOST = 'localhost'
MQTT_HOST = ENV['MQTT_HOST'] || 'localhost'
MQTT_PORT = ENV['MQTT_PORT'] || 1883

def create_standard_client()
  client = MQTT::Client.connect({remote_host: MQTT_HOST,:remote_port=>MQTT_PORT, :reconnect => false, :v311 => true, :clean_session => true,:keep_alive=>2})
  return client
end

def create_unclean_client()
  client = MQTT::Client.connect({remote_host: MQTT_HOST,:remote_port=>MQTT_PORT, :reconnect => false, :v311 => true, :clean_session => false,:client_id=>'ruby_client'})
  return client
end

describe 'massive publish' do
  ap 'Testing MQTT 3.1.1 spec in: %s:%s' % [MQTT_HOST,MQTT_PORT]



  it 'supports several connect options' do
    begin
      client1 = MQTT::Client.connect({remote_host: MQTT_HOST,:remote_port=>MQTT_PORT, :reconnect => false, :v311 => true, :clean_session => false,:client_id=>''}){}
    rescue Exception
    end
    client2 = MQTT::Client.connect({remote_host: MQTT_HOST,:remote_port=>MQTT_PORT, :reconnect => false, :v311 => true, :clean_session => true,:client_id=>''}){}

    client3 = MQTT::Client.connect({remote_host: MQTT_HOST,:remote_port=>MQTT_PORT, :reconnect => false, :v311 => true, :will_topic => 'msg1',:will_payload => 'A',:will_qos=>1,:will_retain=>true})
    sleep 0.25
    client3.disconnect(false)

    client4 = MQTT::Client.connect({remote_host: MQTT_HOST,:remote_port=>MQTT_PORT, :reconnect => false, :v311 => true, :will_topic => 'msg2',:will_payload => 'A',:will_qos=>2,:will_retain=>false})
    sleep 0.25
    client4.disconnect(false)
  end

  it 'Subscribe and unsubscribes' do
    client = create_standard_client()

    client.subscribe(['msg0',0])
    client.subscribe(['msg1',1])
    client.subscribe(['msg2',2])

    client.subscribe(['msg3',2])
    client.unsubscribe('msg3')

    client.subscribe(['msg5',2],['msg6',1],['msg7',0])
    client.unsubscribe('msg5','msg6','msg7')

    client.unsubscribe('inexistent_topic')

    client.subscribe(['#',2])
    client.unsubscribe('#')

    client.subscribe(['+',2])
    client.unsubscribe('+')

    client.subscribe(['asd/+/#',2])
    client.unsubscribe('asd/+/#')

    client.disconnect()
  end

  it 'connects with user and password' do
    client = MQTT::Client.connect({remote_host: MQTT_HOST,:remote_port=>MQTT_PORT, :v311 => true,:username=>'ruby_client',:password=>'password'})

    sleep 1

    client.disconnect()
  end

  it 'Pings server' do
    client = create_standard_client()

    sleep 4

    client.disconnect()
  end

  it 'publish retain messages and clean them' do
    client = create_standard_client()

    client.publish('topic','message',true,2)
    sleep 1
    client.publish('topic','',true,2)

    client.disconnect()
  end

  it 'Publish an get messages' do
    client_sub = create_unclean_client()
    client_pub = create_standard_client()

    client_sub.subscribe(['msg2',2],['msg1',1],['msg0',0],['#',1])

    client_pub.publish('msg2','msg',false,2)
    client_pub.publish('msg1','msg',false,1)
    client_pub.publish('msg0','msg',false,0)
    client_pub.publish('msg0','END',false,0)

    loop do
      topic,message = client_sub.get()

      ap [topic,message]
      break if message == 'END'
    end

    client_sub.disconnect()


    client_pub.publish('msg2','msg',true,2)
    client_pub.publish('msg1','msg',true,1)
    client_pub.publish('msg0','msg',true,0)
    client_pub.publish('msg0','END',true,0)

    client_pub.disconnect()

    client_sub = create_unclean_client()
    ap client_sub.get_batch_messages(nil,0.5,2)
    client_sub.disconnect()
  end
end