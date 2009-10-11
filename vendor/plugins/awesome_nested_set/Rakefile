begin
  require 'jeweler'
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
  exit 1
end
require 'rake/testtask'
require 'rake/rdoctask'
require 'rcov/rcovtask'
require "load_multi_rails_rake_tasks" 

Jeweler::Tasks.new do |s|
  s.name = "awesome_nested_set"
  s.summary = "An awesome nested set implementation for Active Record"
  s.description = s.summary
  s.email = "info@collectiveidea.com"
  s.homepage = "http://github.com/collectiveidea/awesome_nested_set"
  s.authors = ["Brandon Keepers", "Daniel Morrison"]
  s.add_dependency "activerecord", ['>= 1.1']
  s.has_rdoc = true
  s.extra_rdoc_files = [ "README.rdoc"]
  s.rdoc_options = ["--main", "README.rdoc", "--inline-source", "--line-numbers"]
  s.test_files = Dir['test/**/*.{yml,rb}']
end

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the awesome_nested_set plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs += ['lib', 'test']
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the awesome_nested_set plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'AwesomeNestedSet'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

namespace :test do
  desc "just rcov minus html output"
  Rcov::RcovTask.new(:coverage) do |t|
    t.libs << 'test'
    t.test_files = FileList['test/**/*_test.rb']
    t.output_dir = 'coverage'
    t.verbose = true
    t.rcov_opts = %w(--exclude test,/usr/lib/ruby,/Library/Ruby,lib/awesome_nested_set/named_scope.rb --sort coverage)
  end
end