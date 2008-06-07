require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'spec/rake/spectask'

desc 'Run Rspec examples for Globalite'
task :g_spec do
 Rake::Task["spec"].invoke
end

Spec::Rake::SpecTask.new do |t|
   t.spec_files = FileList["spec/**/*_spec.rb"]
end

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the globalite plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the globalite plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Globalite'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end