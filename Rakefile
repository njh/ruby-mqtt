#!/usr/bin/env ruby

$:.push File.expand_path("../lib", __FILE__)

require 'rubygems'
require 'yard'
require 'rspec/core/rake_task'
require "bundler/gem_tasks"

RSpec::Core::RakeTask.new(:spec)

namespace :spec do
  desc 'Run RSpec code examples in specdoc mode'
  RSpec::Core::RakeTask.new(:doc) do |t|
    t.rspec_opts = %w(--backtrace --colour --format doc)
  end
end

desc "Run the specs."
RSpec::Core::RakeTask.new(:test_311,:host,:port) do |t,args|
  usage_msg = "Usage: rake test_311[MQTT_BROKER_ADDRESS,MQTT_PORT]
  i.e. $ rake test_311[192.168.0.3,1883]"

  raise usage_msg if args[:host].nil?

  p args
  ENV['MQTT_HOST'] = args[:host]
  ENV['MQTT_PORT'] = args[:port] || '1883'
  t.pattern = "spec/tc/test_subscribe.rb"
end

namespace :doc do
  YARD::Rake::YardocTask.new

  desc "Generate HTML report specs"
  RSpec::Core::RakeTask.new("spec") do |spec|
    spec.rspec_opts = ["--format", "html", "-o", "doc/spec.html"]
  end
end

task :specs => :spec
task :default => :spec
