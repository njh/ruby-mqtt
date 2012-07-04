ruby-mqtt
=========

Pure Ruby gem that implements the MQTT (Message Queue Telemetry Transport) protocol,
a lightweight protocol for publish/subscribe messaging.


Installing
----------

From local sources:

    $ gem build mqtt.gemspec
    $ gem install mqtt-0.9.0.gem


Synopsis
--------

    require 'rubygems'
    require 'mqtt'
    
    # Async client example
    
    globalClient = MQTT::Client.new("test.mosquitto.org", 1883, client_id)
    # or to get a random ID
    # globalClient = MQTT::Client.new("test.mosquitto.org", 1883)
    
    globalClient.on("connack") do
      globalClient.subscribe( "test/topic" => 2 )
    end
    
    globalClient.on("suback") do |qos|
      puts "suback"
    end
    
    globalClient.on("unsuback") do |packet|
      puts "unsuback"
    end
    
    globalClient.on("message") do |topic, payload, qos, message_id|
      puts "Message arrived: #{topic} :: #{qos} :: #{message_id} :: #{payload}"
    end
    
    globalClient.on("puback") do |message_id|
      puts "Puback received: #{message_id}"
    end
    
    globalClient.on("pubrec") do |message_id|
      puts "Pubrec received: #{message_id}"
      globalClient.pubrel(message_id)
    end
    
    globalClient.on("pubcomp") do |message_id|
      puts "Pubcomp received: #{message_id}"
    end
    
    globalClient.connect
    
    loop {
      sleep 1
    }

Resources
---------

* MQTT Homepage: http://www.mqtt.org/
* GitHub Project: http://github.com/radekg/ruby-mqtt
* Original GitHub Project: http://github.com/njh/ruby-mqtt


Contact
-------

* Async modifications:    Radek Gruchalski
* Author:    Nicholas J Humfrey
* Email:     njh@aelius.com
* Home Page: http://www.aelius.com/njh/
* License:   Distributes under the same terms as Ruby
