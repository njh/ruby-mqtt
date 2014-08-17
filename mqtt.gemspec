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
  gem.summary     = 'Implementation of the MQTT protocol'
  gem.description = 'Pure Ruby gem that implements the MQTT protocol, a lightweight protocol for publish/subscribe messaging.'
  gem.license     = 'MIT' if gem.respond_to?(:license=)

  gem.rubyforge_project = 'mqtt'

  gem.files         = %w(README.md LICENSE.md NEWS.md) + Dir.glob('lib/**/*.rb')
  gem.test_files    = Dir.glob('spec/*_spec.rb')
  gem.executables   = %w()
  gem.require_paths = %w(lib)

  if Gem.ruby_version > Gem::Version.new('1.9')
    gem.add_development_dependency 'bundler',  '>= 1.5.0'
    gem.add_development_dependency 'rake',     '>= 0.10.0'
    gem.add_development_dependency 'yard',     '>= 0.8.0'
    gem.add_development_dependency 'rspec',    '~> 3.0.0'
    gem.add_development_dependency 'simplecov'
  elsif Gem.ruby_version > Gem::Version.new('1.8')
    gem.add_development_dependency 'bundler',  '>= 1.1.0'
    gem.add_development_dependency 'rake',     '~> 0.9.0'
    gem.add_development_dependency 'yard',     '~> 0.8.0'
    gem.add_development_dependency 'rspec',    '~> 3.0.0'
  else
    raise "#{Gem.ruby_version} is an unsupported version of ruby"
  end

end
