#!/usr/bin/env ruby

require 'rubygems'
require 'yard'
require 'rspec/core/rake_task'

namespace :gem do
  desc "Build the mqtt-#{File.read('VERSION').chomp}.gem file"
  task :build do
    sh "gem build mqtt.gemspec"
  end

  desc "Release the mqtt-#{File.read('VERSION').chomp}.gem file"
  task :release do
    sh "gem push mqtt-#{File.read('VERSION').chomp}.gem"
  end
end

RSpec::Core::RakeTask.new(:spec)

desc "Run specs through RCov"
RSpec::Core::RakeTask.new("spec:rcov") do |spec|
  spec.pattern = "./spec/**/*_spec.rb"
  spec.rcov = true
  spec.rcov_opts =  %q[--exclude "spec"]
  spec.rspec_opts =  %q[--format progress]
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
