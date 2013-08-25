#!/usr/bin/env ruby
#
# Authenticate to a server, subscribe to a topic and publish

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'rubygems'
require 'mqtt'
require 'md5'

# The q.m2m.io server uses md5 hashed versions of passwords
def md5(s)
	Digest::MD5.hexdigest(s)
end

MQTT::Client.connect(:remote_host => 'q.m2m.io', :username => 'tim+rubytest@2lemetry.com', :password => md5('P@55w0rd')) do |client|
	puts 'connected'

	# We have to do this in a separate thread or process (or a different computer)
	Thread.new do
		20.times do # We could do it forever, but 20 times is good enough
			sleep(0.5)	# slow it down because computers are too fast
			client.publish('2be57b94bddfae1341d89852fdd6f15b/test/ruby', "The time is now #{Time.now}")
		end
	end

	# when a block is passed to #get, it loops infinitely so this has to be the last line of our program
	client.get("2be57b94bddfae1341d89852fdd6f15b/test/#") do |topic, msg|
		puts "Got message '#{msg}' on topic '#{topic}'"
	end

end

