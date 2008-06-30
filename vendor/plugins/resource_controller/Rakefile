require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

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
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "Do all necessary tagging for a release"
task :release => [:tag_release, :upload_docs]

task :tag_release do
  unless ENV.include?('human') && ENV.include?('tag')
    raise "Usage: rake release human=0.something tag=rel_2.0"
  end

  tag_name   = ENV['tag']
  human_name = ENV['human']
  repo_root  = "http://svn.jamesgolick.com/resource_controller"

  puts "tagging #{human_name}"
  `svn copy #{repo_root}/trunk #{repo_root}/tags/#{tag_name} -m"tagging #{human_name}"`

  puts "deleting previous stable tags"
  `svn rm #{repo_root}/tags/stable -m"deleting previous stable tags"`

  puts "tag stable release"
  `svn copy #{repo_root}/tags/#{tag_name} #{repo_root}/tags/stable -m"tag stable release"`
end

task :upload_docs => :rdoc do
  puts 'Deleting previous rdoc'
  `ssh jamesgolick.com 'rm -Rf /home/apps/jamesgolick.com/public/resource_controller/rdoc'`
  
  puts "Uploading current rdoc"
  `scp -r rdoc jamesgolick.com:/home/apps/jamesgolick.com/public/resource_controller`
  
  puts "Deleting rdoc"
  `rm -Rf rdoc`
end
