#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version            = File.read('VERSION').chomp
  gem.date               = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name               = 'mqtt'
  gem.homepage           = 'http://github.com/njh/ruby-mqtt'
  gem.license            = 'Ruby' if gem.respond_to?(:license=)
  gem.summary            = 'Implementation of the MQTT (Message Queue Telemetry Transport) protocol'
  gem.description        = 'Pure Ruby gem that implements the MQTT (Message Queue Telemetry Transport) protocol, a lightweight protocol for publish/subscribe messaging.'
  gem.rubyforge_project  = 'mqtt'

  gem.author             = 'Nicholas J Humfrey'
  gem.email              = 'njh@aelius.com'

  gem.platform           = Gem::Platform::RUBY
  gem.files              = %w(README COPYING GPL VERSION) + Dir.glob('lib/**/*.rb')
  gem.require_paths      = %w(lib)
  gem.extensions         = %w()
  gem.test_files         = %w()
  gem.has_rdoc           = false

  gem.required_ruby_version      = '>= 1.8.1'
  gem.requirements               = []
  gem.add_development_dependency 'yard',        '>= 0.7.2'
  gem.add_development_dependency 'rspec',       '>= 2.6.0'
  gem.add_development_dependency 'mocha',       '>= 0.10.0'
  gem.post_install_message       = nil
end
