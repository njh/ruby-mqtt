require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'


NAME = "mqtt"
VERS = "0.0.4"
CLEAN.include ['pkg', 'rdoc']

spec = Gem::Specification.new do |s|
  s.name              = NAME
  s.version           = VERS
  s.author            = "Nicholas J Humfrey"
  s.email             = "njh@aelius.com"
  s.homepage          = "http://github.com/njh/ruby-mqtt"
  s.platform          = Gem::Platform::RUBY
  s.summary           = "Implementation of the MQTT (Message Queue Telemetry Transport) protocol" 
  s.rubyforge_project = "mqtt" 
  s.description       = "Pure Ruby gem that implements the MQTT (Message Queue Telemetry Transport) protocol, a lightweight protocol for publish/subscribe messaging."
  s.files             = FileList["Rakefile", "lib/*.rb", "lib/mqtt/*.rb", "examples/*"]
  s.require_path      = "lib"
  
  # rdoc
  s.has_rdoc          = true
  s.extra_rdoc_files  = ["README.md", "NEWS.md", "COPYING"]
end

desc "Default: test the gem."
task :default => [:check_syntax, :rdoc]

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
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = FileList['spec/*_spec.rb']
  t.spec_opts  = ["--colour"]
end
  
desc "Check the syntax of all ruby files"
task :check_syntax do
  `find . -name "*.rb" |xargs -n1 ruby -c |grep -v "Syntax OK"`
  puts "* Done"
end

namespace :spec do
  desc "Generate RCov report"
  Spec::Rake::SpecTask.new(:rcov) do |t|
    t.spec_files  = FileList['spec/*_spec.rb']
    t.rcov        = true
    t.rcov_dir    = 'coverage'
    t.rcov_opts   = ['--text-report', '--exclude', "spec/"] 
  end
  
  desc "Generate specdoc"
  Spec::Rake::SpecTask.new(:doc) do |t|
    t.spec_files  = FileList['spec/*_spec.rb']
    t.spec_opts   = ["--format", "specdoc"]
   end
 
  namespace :doc do
    desc "Generate html specdoc"
    Spec::Rake::SpecTask.new(:html) do |t|
      t.spec_files    = FileList['spec/*_spec.rb']
      t.spec_opts     = ["--format", "html:rspec_report.html", "--diff"]
    end
  end
end



## Documentation
desc "Generate documentation for the library"
Rake::RDocTask.new("rdoc") { |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = "mqtt Documentation"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.main = "README"
  rdoc.rdoc_files.include("README.md", "NEWS.md", "COPYING", "lib/*.rb", "lib/mqtt/*.rb")
}
