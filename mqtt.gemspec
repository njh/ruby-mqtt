#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "mqtt/version"

Gem::Specification.new do |gem|
  gem.name        = 'mqtt'
  gem.version     = MQTT::VERSION
  gem.author      = 'Nicholas J Humfrey'
  gem.email       = 'njh@aelius.com'
  gem.homepage    = 'http://github.com/njh/ruby-mqtt'
  gem.summary     = 'Implementation of the MQTT (Message Queue Telemetry Transport) protocol'
  gem.description = 'Pure Ruby gem that implements the MQTT (Message Queue Telemetry Transport) protocol, a lightweight protocol for publish/subscribe messaging.'
  gem.license     = 'Ruby' if gem.respond_to?(:license=)

  gem.rubyforge_project = 'mqtt'

  gem.files         = %w(README COPYING GPL NEWS) + Dir.glob('lib/**/*.rb')
  gem.test_files    = Dir.glob('spec/*_spec.rb')
  gem.executables   = %w()
  gem.require_paths = %w(lib)

  gem.add_development_dependency 'bundler',     '>= 1.0.7'
  gem.add_development_dependency 'yard',        '>= 0.7.2'
  gem.add_development_dependency 'rake',        '>= 0.8.7'
  gem.add_development_dependency 'rspec',       '>= 2.6.0'
  gem.add_development_dependency 'mocha',       '>= 0.10.0'
end
