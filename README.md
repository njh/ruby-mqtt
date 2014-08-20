[![Build Status](https://travis-ci.org/njh/ruby-mqtt.svg)](https://travis-ci.org/njh/ruby-mqtt)

ruby-mqtt
=========

Pure Ruby gem that implements the MQTT protocol, a lightweight protocol for publish/subscribe messaging.


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
      # If you pass a block to the get method, then it will loop
      c.get('test') do |topic,message|
        puts "#{topic}: #{message}"
      end
    end


Limitations
-----------

 * Only QOS 0 currently supported
 * Automatic re-connects to the server are not supported


Resources
---------

* API Documentation: http://rubydoc.info/gems/mqtt/frames
* Protocol Specification v3.1.1: http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/mqtt-v3.1.1.html
* Protocol Specification v3.1: http://public.dhe.ibm.com/software/dw/webservices/ws-mqtt/mqtt-v3r1.html
* MQTT Homepage: http://www.mqtt.org/
* GitHub Project: http://github.com/njh/ruby-mqtt


License
-------

The ruby-mqtt gem is licensed under the terms of the MIT license.
See the file LICENSE for details.


Contact
-------

* Author:    Nicholas J Humfrey
* Email:     njh@aelius.com
* Home Page: http://www.aelius.com/njh/
