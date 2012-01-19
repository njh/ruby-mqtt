ruby-mqtt
=========

Pure Ruby gem that implements the MQTT (Message Queue Telemetry Transport) protocol,
a lightweight protocol for publish/subscribe messaging.


Installing
----------

You may get the latest stable version from Rubygems:

    $ gem install mqtt


Synopsis
--------

    require 'rubygems'
    require 'mqtt'
    
    # Publish example
    MQTT::Client.connect('test.mosquitto.org') do |c|
      c.publish('topic', 'message')
    end
    
    # Subscribe example
    MQTT::Client.connect('test.mosquitto.org') do |c|
      c.get('test') do |topic,message|
        puts "#{topic}: #{message}"
      end
    end


Limitations
-----------

 * Only QOS 0 currently supported


Resources
---------

* MQTT Homepage: http://www.mqtt.org/
* GitHub Project: http://github.com/njh/ruby-mqtt
* API Documentation: http://rubydoc.info/gems/mqtt/frames


Contact
-------

* Author:    Nicholas J Humfrey
* Email:     njh@aelius.com
* Home Page: http://www.aelius.com/njh/
* License:   Distributes under the same terms as Ruby
