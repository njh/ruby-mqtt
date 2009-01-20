require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/testtask'

NAME = "mqtt"
VERS = "0.0.1"
CLEAN.include ['pkg', 'rdoc']

spec = Gem::Specification.new do |s|
  s.name              = NAME
  s.version           = VERS
  s.author            = "Nicholas J Humfrey"
  s.email             = "njh@aelius.com"
  s.homepage          = "http://mqtt.rubyforge.org"
  s.platform          = Gem::Platform::RUBY
  s.summary           = "Implementation of the MQTT (Message Queue Telemetry Transport) protocol" 
  s.rubyforge_project = "mqtt" 
  s.description       = "Pure Ruby gem that implements the MQTT (Message Queue Telemetry Transport) protocol, a lightweight protocol for publish/subscribe messaging."
  s.files             = FileList["Rakefile", "lib/*.rb", "lib/mqtt/*.rb", "examples/*"]
  s.require_path      = "lib"
  
  # rdoc
  s.has_rdoc          = true
  s.extra_rdoc_files  = ["README", "NEWS", "COPYING"]
  
  # Dependencies
  s.add_dependency "rake"
end

desc "Default: package up the gem."
task :default => :package

task :build_package => [:repackage]
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = false
  pkg.need_tar = true
  pkg.gem_spec = spec
end

desc "Run :package and install the resulting .gem"
task :install => :package do
  sh %{sudo gem install --local pkg/#{NAME}-#{VERS}.gem}
end

desc "Run :clean and uninstall the .gem"
task :uninstall => :clean do
  sh %{sudo gem uninstall #{NAME}}
end



## Testing
desc "Run all the specification tests"
Rake::TestTask.new(:spec) do |t|
  t.warning = true
  t.verbose = true
  t.pattern = 'spec/*_spec.rb'
end
  
desc "Check the syntax of all ruby files"
task :check_syntax do
  `find . -name "*.rb" |xargs -n1 ruby -c |grep -v "Syntax OK"`
  puts "* Done"
end

desc "Create rspec report as HTML"
task :rspec_html do
  sh %{spec -f html spec/mqtt_spec.rb > rspec_results.html}
end

## Documentation
desc "Generate documentation for the library"
Rake::RDocTask.new("rdoc") { |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = "mqtt Documentation"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.main = "README"
  rdoc.rdoc_files.include("README", "NEWS", "COPYING", "lib/*.rb", "lib/mqtt/*.rb")
}

desc "Upload rdoc to rubyforge"
task :upload_rdoc => [:rdoc] do
  sh %{/usr/bin/scp -r -p rdoc/* mqtt.rubyforge.org:/var/www/gforge-projects/mqtt}
end
