$:.unshift(File.dirname(__FILE__))

require 'bundler'
Bundler.require(:default, :development)
require 'mqtt'

#HOST = 'localhost'
HOST = '10.100.0.139'

def send_publish(start,delta,sleep_time)
  id = start
  loop do
    client = MQTT::Client.connect(HOST)

    client.publish('cuack','cuackmessage: ' + id.to_s,false,2)
    id += delta
    client.disconnect()
    sleep sleep_time
  end
end

describe 'massive publish' do
  it 'send messages' do
    t1 = Thread.new{send_publish(1,1,1.0)}
    t2 = Thread.new{send_publish(1,1,1.1)}
    t3 = Thread.new{send_publish(1,1,1.2)}
    t4 = Thread.new{send_publish(1,1,1.3)}
    t5 = Thread.new{send_publish(1,1,1.4)}
    t6 = Thread.new{send_publish(1,1,1.5)}
    t7 = Thread.new{send_publish(1,1,1.6)}


    t1.join
  end
end