$:.unshift(File.join(File.dirname(__FILE__),'..','lib'))

require 'bundler'

Bundler.require(:default, :development)

SimpleCov.start do
  add_filter '/spec/'
end

def fixture_path(name)
  File.join(File.dirname(__FILE__), 'fixtures', name.to_s)
end
