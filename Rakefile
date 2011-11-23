#!/usr/bin/env ruby

$:.push File.expand_path("../lib", __FILE__)

require 'rubygems'
require 'yard'
require 'rspec/core/rake_task'

require "mqtt/version"

namespace :gem do
  desc "Build the mqtt-#{MQTT::VERSION}.gem file"
  task :build do
    sh "gem build mqtt.gemspec"
  end

  desc "Release the mqtt-#{MQTT::VERSION}.gem file"
  task :release do
    sh "gem push mqtt-#{MQTT::VERSION}.gem"
  end
end

RSpec::Core::RakeTask.new(:spec)

namespace :spec do
  desc 'Run RSpec code examples in specdoc mode'
  RSpec::Core::RakeTask.new(:doc) do |t|
    t.rspec_opts = %w(--backtrace --colour --format doc)
  end

  desc 'Run RSpec code examples with rcov'
  RSpec::Core::RakeTask.new(:rcov) do |t|
    t.rcov = true
    t.rcov_opts = %w(--text-report --exclude /gems/,/Library/,/usr/,.bundle,spec)
    t.rspec_opts = %w(--no-colour --format progress)
  end
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
