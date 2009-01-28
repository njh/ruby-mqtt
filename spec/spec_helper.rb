begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end

require 'rubygems'
require 'mocha'

$:.unshift(File.dirname(__FILE__) + '/../lib')

Spec::Runner.configure do |config|
  config.mock_with :mocha
end
