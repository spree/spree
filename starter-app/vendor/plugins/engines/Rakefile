require 'rake'
require 'rake/rdoctask'
require 'tmpdir'

task :default => :doc

desc 'Generate documentation for the engines plugin.'
Rake::RDocTask.new(:doc) do |doc|
  doc.rdoc_dir = 'doc'
  doc.title    = 'Engines'
  doc.main     = "README"
  doc.rdoc_files.include("README", "CHANGELOG", "MIT-LICENSE")
  doc.rdoc_files.include('lib/**/*.rb')
  doc.options << '--line-numbers' << '--inline-source'
end

desc 'Run the engine plugin tests within their test harness'
task :cruise do
  # checkout the project into a temporary directory
  version = "rails_2.0"
  test_dir = "#{Dir.tmpdir}/engines_plugin_#{version}_test"
  puts "Checking out test harness for #{version} into #{test_dir}"
  `svn co http://svn.rails-engines.org/test/engines/#{version} #{test_dir}`

  # run all the tests in this project
  Dir.chdir(test_dir)
  load 'Rakefile'
  puts "Running all tests in test harness"
  ['db:migrate', 'test', 'test:plugins'].each do |t|
    Rake::Task[t].invoke
  end  
end