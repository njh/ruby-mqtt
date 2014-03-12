$:.unshift(File.dirname(__FILE__))

require 'bundler'
Bundler.require(:default, :development)
require 'mqtt'

HOST = 'localhost'
#HOST = '10.100.0.139'

def create_standard_client()
  client = MQTT::Client.connect({remote_host: HOST,remote_port: 1883, :reconnect => true, :v311 => true, :clean_session => false})
  return client
end

describe 'support ACK' do
  # it 'send messages' do
  #   client = create_standard_client()

  #   client.publish('topico','cuack1',false,0)
  #   client.publish('topico','cuack2',false,1)
  #   client.publish('topico','cuack1',false,2)

  #   client.disconnect()
  # end

  # it 'support disconnection' do
  #   client = client = create_standard_client()
  #   loop do
  #     client.publish('topico','cuack1',false,0)
  #     sleep 0.25
  #   end
  #   client.disconnect()
  # end

  it 'Support get batch messages' do
    client = create_standard_client()
    client.get(['cuack',2]) do |topic,message|
      ap [topic,message]
    end

    client.disconnect()
  end

  # it 'support batch processing' do
  #   client = MQTT::Client.connect({remote_host: HOST,remote_port: 1883, :reconnect => true,:clean_session => false,:client_id => 'cuack_user' })
  #   ap client.get_batch_messages(['cuack',2],0.5,20)
  #   client.disconnect()
  # end

  # it 'Support publishing' do
  #   loop do
  #     client = MQTT::Client.connect({remote_host: HOST,remote_port: 1883, :reconnect => true,:clean_session => false,:client_id => 'cuack_user2' })
  #     ap client.get_batch_messages(['cuack',2],0.5,5)
  #     client.disconnect()
  #   end
  # end

  # it 'Raise exception when message is too long' do
  #   client = create_standard_client()

  #   expect { client.publish('topic/topic_leaf+','message',false,1) }.to raise_error(MQTT::ProtocolException)
  #   expect { client.publish('topic/topic_leaf*','message',false,1) }.to raise_error(MQTT::ProtocolException)

  #   client.disconnect()
  # end
end