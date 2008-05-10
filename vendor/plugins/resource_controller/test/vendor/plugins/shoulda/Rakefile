require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

#require 'tasks/list_tests.rake'

# Test::Unit::UI::VERBOSE

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.pattern = 'test/{unit,functional,other}/**/*_test.rb'
  t.verbose = false
end

Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "Shoulda -- Making tests easy on the fingers and eyes"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.template = "#{ENV['template']}.rb" if ENV['template']
  rdoc.rdoc_files.include('README', 'lib/**/*.rb')
}

desc 'Update documentation on website'
task :sync_docs => 'rdoc' do
  `rsync -ave ssh doc/ dev@dev.thoughtbot.com:/home/dev/www/dev.thoughtbot.com/shoulda`
end

desc 'Default: run tests.'
task :default => ['test']
