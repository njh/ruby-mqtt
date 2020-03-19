$:.unshift(File.join(File.dirname(__FILE__),'..','lib'))

require 'rubygems'
require 'bundler'

Bundler.require(:default, :development)

unless RUBY_VERSION =~ /^1\.8/
  SimpleCov.start do
    add_filter '/spec/'
  end
end


def fixture_path(name)
  File.join(File.dirname(__FILE__), 'fixtures', name.to_s)
end
