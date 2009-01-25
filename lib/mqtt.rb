#!/usr/bin/env ruby

require 'mqtt/client'

# Pure-ruby implementation of the MQTT protocol
module MQTT

  PACKET_TYPES = [
    nil,
    :connect,      # Client request to connect to Broker
    :connack,      # Connect Acknowledgment
    :publish,      # Publish message
    :puback,       # Publish Acknowledgment
    :pubrec,       # Publish Received (assured delivery part 1)
    :pubrel,       # Publish Release (assured delivery part 2)
    :pubcomp,      # Publish Complete (assured delivery part 3)
    :subscribe,    # Client Subscribe request
    :suback,       # Subscribe Acknowledgment
    :unsubscribe,  # Client Unsubscribe request
    :unsuback,     # Unsubscribe Acknowledgment
    :pingreq,      # PING Request
    :pingresp,     # PING Response
    :disconnect,   # Client is Disconnecting
    nil
  ]
  
  class Exception < Exception
  
  end

  class ProtocolException < MQTT::Exception
  
  end
  
  class NotConnectedException < MQTT::Exception
  
  end

end
