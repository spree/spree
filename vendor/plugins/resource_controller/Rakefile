require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require File.dirname(__FILE__)+'/lib/resource_controller/version'
Dir['tasks/**.rake'].each { |tasks| load tasks }

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the ResourceController plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the ResourceController plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'ResourceController'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

task :upload_docs => :rdoc do
  puts 'Deleting previous rdoc'
  `ssh jamesgolick.com 'rm -Rf /home/apps/jamesgolick.com/public/resource_controller/rdoc'`
  
  puts "Uploading current rdoc"
  `scp -r rdoc jamesgolick.com:/home/apps/jamesgolick.com/public/resource_controller`
  
  puts "Deleting rdoc"
  `rm -Rf rdoc`
end
