ruby-mqtt
=========

Pure Ruby gem that implements the MQTT (Message Queue Telemetry Transport) protocol, a lightweight protocol for publish/subscribe messaging.


Installing
----------

You may get the latest stable version from Rubygems:

    $ gem install mqtt

Synopsis
--------

    require 'rubygems'
    require 'mqtt'
    
    # Publish example
    MQTT::Client.connect('mqtt.example.com') do |c|
      c.publish('topic', 'message')
    end
    
    # Subscribe example
    MQTT::Client.connect('mqtt.example.com') do |c|
      c.subscribe('test')
      loop do
        topic,message = c.get
        puts "#{topic}: #{message}"
      end
    end


TODO
----

* Implement Will and Testament
* Process acknowledgement packets / Implement QOS 1 in client
* More validations of data/parameters
* More error checking and exception throwing
  - Check that packet data is valid - don't blindly read values
  - Subscribe and Unsubscribe packets should always have QOS of 1
* More examples
* Integration tests
* Refactor to add callbacks that are called from seperate thread
* Implement QOS Level 2 in client
* Prevent proxy from connecting to itself
* Add support for binding socket to specific local address


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
