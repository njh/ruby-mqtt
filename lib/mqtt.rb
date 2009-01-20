#!/usr/bin/env ruby

require 'mqtt/client'

# Pure-ruby implementation of the MQTT protocol
module MQTT

  QOS_TYPES = [
    :qos0,    # At most once - Fire and Forget
    :qos1,    # At least once - Acknowledged delivery
    :qos2     # Exactly once - Assured delivery
  ]

  class Exception < Exception
  
  end
  
  class NotConnectedException < MQTT::Exception
  
  end

end
