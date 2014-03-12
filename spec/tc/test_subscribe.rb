$:.unshift(File.dirname(__FILE__))

require 'bundler'
Bundler.require(:default, :development)
require 'mqtt'

# HOST = 'localhost'
HOST = '10.100.0.139'

def create_standard_client()
  client = MQTT::Client.connect({remote_host: HOST,remote_port: 1883, :reconnect => false, :v311 => true, :clean_session => true,:keep_alive=>2})
  return client
end

def create_unclean_client()
  client = MQTT::Client.connect({remote_host: HOST,remote_port: 1883, :reconnect => false, :v311 => true, :clean_session => false,:client_id=>'ruby_client'})
  return client
end

describe 'massive publish' do
  it 'supports several connect options' do
    begin
      client1 = MQTT::Client.connect({remote_host: HOST,remote_port: 1883, :reconnect => false, :v311 => true, :clean_session => false,:client_id=>''}){}
    rescue Exception
    end
    client2 = MQTT::Client.connect({remote_host: HOST,remote_port: 1883, :reconnect => false, :v311 => true, :clean_session => true,:client_id=>''}){}

    client3 = MQTT::Client.connect({remote_host: HOST,remote_port: 1883, :reconnect => false, :v311 => true, :will_topic => 'cuack1',:will_payload => 'A',:will_qos=>1,:will_retain=>true})
    sleep 0.25
    client3.disconnect(false)

    client4 = MQTT::Client.connect({remote_host: HOST,remote_port: 1883, :reconnect => false, :v311 => true, :will_topic => 'cuack2',:will_payload => 'A',:will_qos=>2,:will_retain=>false})
    sleep 0.25
    client4.disconnect(false)
  end

  it 'Subscribe and unsubscribes' do
    client = create_standard_client()

    client.subscribe(['cuack0',0])
    client.subscribe(['cuack1',1])
    client.subscribe(['cuack2',2])

    client.subscribe(['cuack3',2])
    client.unsubscribe('cuack3')

    client.subscribe(['cuack5',2],['cuack6',1],['cuack7',0])
    client.unsubscribe('cuack5','cuack6','cuack7')

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
    client = MQTT::Client.connect({remote_host: HOST,remote_port: 1883, :v311 => true,:username=>'ruby_client',:password=>'password'})

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

    client_sub.subscribe(['cuack2',2],['cuack1',1],['cuack0',0],['#',1])

    client_pub.publish('cuack2','cuack',false,2)
    client_pub.publish('cuack1','cuack',false,1)
    client_pub.publish('cuack0','cuack',false,0)
    client_pub.publish('cuack0','END',false,0)

    loop do
      topic,message = client_sub.get()

      ap [topic,message]
      break if message == 'END'
    end

    client_sub.disconnect()


    client_pub.publish('cuack2','cuack',true,2)
    client_pub.publish('cuack1','cuack',true,1)
    client_pub.publish('cuack0','cuack',true,0)
    client_pub.publish('cuack0','END',true,0)

    client_pub.disconnect()

    client_sub = create_unclean_client()
    ap client_sub.get_batch_messages(nil,0.5,2)
    client_sub.disconnect()
  end
end