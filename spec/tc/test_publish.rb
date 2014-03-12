$:.unshift(File.dirname(__FILE__))

require 'bundler'
Bundler.require(:default, :development)
require 'mqtt'

HOST = 'localhost'
#HOST = '10.100.0.139'

WAIT_TIME = 0.25

def create_standard_client()
  client = MQTT::Client.connect({remote_host: HOST,remote_port: 1883, :reconnect => false, :v311 => true, :clean_session => true})
  return client
end

describe 'massive publish' do
  it 'send messages' do
    client = create_standard_client()

    client.publish('cuack0','cuackmessage0',false,0)
    sleep WAIT_TIME
    client.publish('cuack1','cuackmessage1',false,1)
    sleep WAIT_TIME
    client.publish('cuack2','cuackmessage2',false,2)
    sleep WAIT_TIME

    client.publish('cuack0','cuackmessage0',true,0)
    sleep WAIT_TIME
    client.publish('cuack1','cuackmessage1',true,1)
    sleep WAIT_TIME
    client.publish('cuack2','cuackmessage2',true,2)
    sleep WAIT_TIME

    client.disconnect()
  end
end