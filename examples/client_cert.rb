#!/usr/bin/env ruby
#
# Connect to a MQTT server using SSL/TLS Client Certificate,
# send a single message and then receive it back
#

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'openssl'
require 'mqtt'


# List the supported SSL/TLS protocol versions
p OpenSSL::SSL::SSLContext::METHODS

# Ruby 1.8 / 1.9 only support TLSv1
client = MQTT::Client.new('localhost', :ssl => :TLSv1)
client.ca_file = './ca.pem'
client.cert_file = './client.crt'
client.key_file = './client.key'

client.connect do
  client.subscribe('test')

  # Send a message
  client.publish('test', "hello world")

  # If you pass a block to the get method, then it will loop
  topic, message = client.get
  p [topic, message]
end
