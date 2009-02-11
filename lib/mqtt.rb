#!/usr/bin/env ruby

# Pure-ruby implementation of the MQTT protocol
module MQTT

  class Exception < Exception
  
  end

  class ProtocolException < MQTT::Exception
  
  end
  
  class NotConnectedException < MQTT::Exception
  
  end

end
