Ruby MQTT NEWS
==============

Ruby MQTT Version 0.0.8 (2011-02-04)
------------------------------------

* Implemented Last Will and Testament feature.
* Renamed dup attribute to duplicate to avoid method name clash.
* Made the random client_id generator a public class method.


Ruby MQTT Version 0.0.7 (2011-01-19)
------------------------------------

* You can now pass a topic and block to client.get
* Added MQTT::Client.connect class method.


Ruby MQTT Version 0.0.5 (2011-01-18)
------------------------------------

* Implemented setting username and password (MQTT 3.1)
* Renamed clean_start to clean_session
* Started using autoload to load classes
* Modernised Gem building mechanisms


Ruby MQTT Version 0.0.4 (2009-02-22)
------------------------------------

* Re-factored packet encoding/decoding into one class per packet type.
* Added MQTT::Proxy class for implementing an MQTT proxy.


Ruby MQTT Version 0.0.3 (2009-02-08)
------------------------------------

* Added checking of Connection Acknowledgement.
* Automatic client identifier generation.


Ruby MQTT Version 0.0.2 (2009-02-03)
------------------------------------

* Added support for packets longer than 127 bytes.


Ruby MQTT Version 0.0.1 (2009-02-01)
------------------------------------

* Initial Release.
