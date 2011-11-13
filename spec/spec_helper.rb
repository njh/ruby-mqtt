require 'rubygems'
require 'rspec'     # Rspec 2
require 'mocha'

$:.unshift(File.dirname(__FILE__) + '/../lib')

RSpec.configure do |config|
  config.mock_with :mocha
end
