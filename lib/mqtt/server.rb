require 'logger'

class MQTT::Server
  attr_accessor :address
  attr_accessor :port
  attr_accessor :logger

  def initialize(argv)
    # FIXME: do options parsing here
    self.address = "0.0.0.0"
    self.port = MQTT::DEFAULT_PORT
    self.logger = Logger.new(STDOUT)
    self.logger.level = Logger::INFO
  end

  def run
    EventMachine.run do
      # hit Control + C to stop
      Signal.trap("INT")  { EventMachine.stop }
      Signal.trap("TERM") { EventMachine.stop }

      logger.info("Starting MQTT server on #{address}:#{port}")
      EventMachine.start_server(address, port, MQTT::ServerConnection, logger)
    end
  end

end
