$:.unshift(File.join(File.dirname(__FILE__),'..','lib'))

require 'rubygems'
require 'bundler'

Bundler.require(:default, :development)

# This is needed by rcov
require 'rspec/autorun'

RSpec.configure do |config|
  config.mock_framework = :mocha
end
