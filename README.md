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
    
    globalClient.on_connack do
      globalClient.subscribe( "test/topic" => 2 )
    end
    
    globalClient.on_suback do |qos|
      puts "suback"
    end
    
    globalClient.on_unsuback do |packet|
      puts "unsuback"
    end
    
    globalClient.on_message do |topic, payload, qos, message_id|
      puts "Message arrived: #{topic} :: #{qos} :: #{message_id} :: #{payload}"
    end
    
    globalClient.on_puback do |message_id|
      puts "Puback received: #{message_id}"
    end
    
    globalClient.on_pubrec do |message_id|
      puts "Pubrec received: #{message_id}"
      globalClient.pubrel(message_id)
    end
    
    globalClient.on_pubcomp do |message_id|
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
