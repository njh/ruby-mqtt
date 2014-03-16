ruby-mqtt
=========

Pure Ruby gem that implements the MQTT (Message Queue Telemetry Transport) protocol. MQTT is a machine-to-machine (M2M)/"Internet of Things" connectivity protocol. Designed as an extremely lightweight publish/subscribe messaging transport, it is useful for connections with remote locations where a small code footprint is required and/or network bandwidth is at a premium.


## Table of Contents ##
- [Installation](#installation)
- [MQTT Protocol Summary](#mqtt-protocol)
- [Library Usage](#synopsis)
- [Resources](#resources)
- [License](#license)
- [Contact](#contact)

Installation
------------

You may get the latest stable version from Rubygems at:

~~$ gem install mqtt~~ Unavailable while the merge request is not finished.

Optionally, you can use this fork using bundler:

    gem 'mqtt', :git => 'https://github.com/tierconnect/ruby-mqtt.git'

## MQTT Protocol ##


MQTT is a lightweight messaging protocol based on message publishing/subscription, for use on top of a TCP/IP protocol. Every MQTT message includes a topic that classifies it. MQTT servers use topics to determine which subscribers should receive messages published to the server.

To provide more flexibility, MQTT supports a hierarchical topic namespace. This allows app designers to organize topics to simplify their management. Levels in the hierarchy are delimited by the '/' character.


### Wildcards ###

For subscriptions, two wildcard characters are supported:

* A '#' character represents a complete sub-tree of the hierarchy, and thus, must be the last character in a subscription topic string, such as SENSOR/#. This will match any topic starting with SENSOR/, such as SENSOR/1/TEMP and SENSOR/2/HUMIDITY.
	
* A '+' character represents a single level of the hierarchy and is used between delimiters. For example, SENSOR/+/TEMP will match SENSOR/1/TEMP and SENSOR/2/TEMP.

Publishers are not allowed to use the wildcard characters in their topic names.


### QoS ###

Quality of Service is a networking term that specifies a guaranteed throughput level. Quality of service technology is intended for guaranteed timely delivery of specific application data or resources to a particular destination or destinations.

Different levels of QoS are used in this ruby-mqtt interface:

* QoS Level 0 - where a message is sent by the user to the server and all those currently connected to it. No confirmation of reception is returned to the user. 
* QoS Level 1 - where the message is sent under the same conditions described for QoS Level 0, and a reception acknowledgement is issued by the server. 
* QoS Level 2 - where a message is sent to the server requesting acknnowledgement of readiness for reception. The server responds indicating its readiness to receive the message. Afterwards, the same conditions apply as for QoS Level 1.

Functionality does not change while using any of the 3 above-mentioned conditions. However, a higher level of QoS is oriented towards higher reliability and will, consequently, result in a slight decrease in speed.


### Retain messages ###

The use of this capability enables the user to mark a message to be retained for future use and users. The system retains the message and publishes it for each subsequent subscriber. There is a limit of 1 retained message per user per topic!!!


### Clean/Unclean sessions ###

A clean session implies beginning a new session from scratch. When you connect an MQTT client application using the MqttClient.connect method, the client identifies the connection using the client identifier and the address of the server. The server checks whether session information has been saved from a previous connection to the server. If a previous session still exists, and cleanSession=true, then the previous session information at the client and server is cleared. If cleanSession=false the previous session is resumed. If no previous session exists, a new session is started.

In an unclean or "dirty" session, the user specifies whether to continue the last session saved. Otherwise, the system will launch a brand new session. A previously-saved session is related to the user's subscription and it will save the subscription and all saved messages related to that subscription if QoS>0.

Upon opening of an unclean session, all messages received while the user was disconnected from the system will appear.


### Will message ###

If an MQTT client connection ends unexpectedly, the user can configure mqtt to send a "last will and testament" message. The content of the message must be predefined, as well as the topic to send it to. The "last will" is a connection property. It must be created before connecting the client.

The will message is comprised of a topic, payload, QoS level and a retain value.



## Synopsis ##


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

Connection:

    client = MQTT::Client.connect('mqtt://myserver.example.com')
    client = MQTT::Client.connect('mqtt://user:pass@myserver.example.com')
    client = MQTT::Client.connect('myserver.example.com')
    client = MQTT::Client.connect('myserver.example.com', 18830)
    client = MQTT::Client.connect({:remote_host => 'myserver.example.com',:remote_port => 1883 ... })
    
SSL Connection

    client = MQTT::Client.new({:remote_host => 'myserver.example.com',:remote_port => 1883,:ssl => true })
    client.cert_file = path_to('client.pem')
    client.key_file  = path_to('client.key')
    client.ca_file   = path_to('root-ca.pem')
    client.connect()

The connection can be made without the use of a block:

    client = MQTT::Client.connect('myserver.example.com', 18830)
       #client stuff
    client.disconnect()

Or, if using a block, with an implicit disconnection at the end of the block.

    MQTT::Client.connect('myserver.example.com', 18830) do |client|
       #client stuff
    end


The default options for the map parameter are:

    ATTR_DEFAULTS = {
       :remote_host => nil,
       :remote_port => nil,
    
       :keep_alive => 15,
       :clean_session => true,
       :client_id => nil,
       :ack_timeout => 5,
       :username => nil,
       :password => nil,
    
       :will_topic => nil,
       :will_payload => nil,
       :will_qos => 0,
       :will_retain => false,
    
       :reconnect => false,
       :ssl => false,
       :v311  => false
    }

* :keep_alive - Time to determine a live client/server
* :clean_session - Start with a new session or an unclean one (subscriptions wiped or saved, respectively)
* :client_id - Client id sent to the server. Autogenerated if nil.
* :ack_timeout - Timeout to receive an ACK.
* :username - If the servers supports auth, the username.
* :password - If the servers supports auth, the username.

A will topic is a message that the server should send in the scenario of a client disconnection.
* :will_topic
* :will_payload
* :will_qos
* :will_retain

Miscellanea parameters.

* :reconnect - If the connection is dropped, reconnect.
* :ssl - If the connection will use a ssl connection
* :v311 By default, messages are sent complying with the MQTT 3.1.0 spec. With this parameter set as "true", the messages are sent based on the MQTT 3.1.1 spec.

Subscribe
Select topic and qos level (0 if not provided)

    client.subscribe( 'a/b' )
    client.subscribe( 'a/b', 'c/d' )
    client.subscribe( ['a/b',0], ['c/d',1] )
    client.subscribe( 'a/b' => 0, 'c/d' => 1 )

Unsubscribe

    client.unsubscribe('topic1','topic2','topic3')

Publish

    client.publish(topic, payload, retain=false, qos=0)

Get Messages

    client.get(topic) do |topic,message|
        
    end

or

    topic,message = client.get(topic)

Limitations
-----------

 * ~~Only QOS 0 is currently supported~~


Resources
---------

* MQTT Homepage: http://www.mqtt.org/
* GitHub Project: http://github.com/njh/ruby-mqtt
* API Documentation: http://rubydoc.info/gems/mqtt/frames

License
-------

The ruby-mqtt gem is licensed under the terms of the MIT license.
See the file LICENSE for details.

Contact
-------

* Author:    Nicholas J Humfrey
* Email:     njh@aelius.com
* Home Page: http://www.aelius.com/njh/
