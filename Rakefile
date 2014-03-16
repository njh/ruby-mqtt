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
RSpec::Core::RakeTask.new(:test_311,:host,:port,:exclude_wildcard_test,:only_basic_test,:username,:password) do |rspec,args|
  usage_msg = "Usage: rake test_311[MQTT_BROKER_ADDRESS,MQTT_PORT,exclude_wildcard_test,only_basic_test,USERNAME,PASSWORD]
  i.e. $ rake test_311[192.168.0.3,1883,false,false,mqtt_user,user_password]
  i.e. $ rake test_311[192.168.0.3]"

  args.with_defaults(:port => '1883', :exclude_wildcard_test => 'false',:only_basic_test => 'false',:username => nil,:password =>nil)
  exclude_wildcard_test   = (args[:exclude_wildcard_test] == 'true')
  only_basic_test = (args[:only_basic_test] == 'true')

  raise usage_msg if args[:host].nil?
  raise usage_msg if args[:username].nil? == false and args[:password].nil?

  ENV['MQTT_HOST'] = args[:host]
  ENV['MQTT_PORT'] = args[:port]
  ENV['MQTT_USERNAME'] = args[:username]
  ENV['MQTT_PASSWORD'] = args[:password]

  opts = ["--format", "doc",'--colour']
  if exclude_wildcard_test
    opts << '--tag'
    opts << '~wildcard_test'
  end

  if only_basic_test
    opts << '--tag'
    opts << 'basic'
  end
  rspec.rspec_opts = opts
  rspec.pattern = "spec/test_311.rb"
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
