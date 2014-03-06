$:.unshift(File.dirname(__FILE__))

require 'bundler'
Bundler.require(:default, :development)
require 'mqtt'

#host = 'localhost'
host = '10.100.0.139'

describe 'support ACK' do
  # it 'send messages' do
  #   client = MQTT::Client.connect(host)
  #   client.publish('topico','cuack1',false,0)
  #   client.publish('topico','cuack2',false,1)
  #   client.publish('topico','cuack1',false,2)
  #   client.disconnect()
  # end

  it 'support disconnection' do
    client = MQTT::Client.connect({remote_host: host,remote_port: 1883, :reconnect => true,:clean_session => false})
    loop do
      client.publish('topico','cuack1',false,0)
      sleep 0.25
    end
    client.disconnect()
  end

  # it 'Support publishing' do
  #   client = MQTT::Client.connect({remote_host: host,remote_port: 1883, :reconnect => true,:clean_session => false,:client_id => 'cuack_user2' })
  #   client.get(['cuack',2]) do |topic,message|
  #     ap [topic,message]
  #   end

  #   client.disconnect()
  # end

  # it 'support batch processing' do
  #   client = MQTT::Client.connect({remote_host: host,remote_port: 1883, :reconnect => true,:clean_session => false,:client_id => 'cuack_user2' })
  #   ap client.get_batch_messages(['cuack',2],0.5,20)
  #   client.disconnect()
  # end
end