$:.unshift(File.join(File.dirname(__FILE__),'..','lib'))

require 'rubygems'
require 'bundler'

Bundler.require(:default, :development)

SimpleCov.start
