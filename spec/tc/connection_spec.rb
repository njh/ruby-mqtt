$:.unshift(File.dirname(__FILE__))

require 'bundler'
Bundler.require(:default, :development)
require 'mqtt'

host = '10.100.0.139'
#host = '10.100.1.209'

describe 'support ACK' do
  # it 'send message' do
  #   MQTT::Client.connect(host) do |c|
  #     c.publish('topico','cuack1',false,0)
  #     c.publish('topico','cuack2',false,1)
  #     c.publish('topico','cuack1',false,2)
  #   end
  # end

  it 'Support publishing' do
    MQTT::Client.connect({remote_host: host,remote_port: 1883, qos: 1,:clean_session => false,:client_id => 'cuack_user2' }) do |c|
      c.get(['cuack',1]) do |topic,message|
        ap [topic,message]
      end
    end
  end
end