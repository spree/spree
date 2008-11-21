require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require 'paperclip'

desc 'Default: run unit tests.'
task :default => [:clean, :test]

desc 'Test the paperclip plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'profile'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Start an IRB session with all necessary files required.'
task :shell do |t|
  chdir File.dirname(__FILE__)
  exec 'irb -I lib/ -I lib/paperclip -r rubygems -r active_record -r tempfile -r init'
end

desc 'Generate documentation for the paperclip plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = 'Paperclip'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc 'Update documentation on website'
task :sync_docs => 'rdoc' do
  `rsync -ave ssh doc/ dev@dev.thoughtbot.com:/home/dev/www/dev.thoughtbot.com/paperclip`
end

desc 'Clean up files.'
task :clean do |t|
  FileUtils.rm_rf "doc"
  FileUtils.rm_rf "tmp"
  FileUtils.rm_rf "pkg"
  FileUtils.rm "test/debug.log" rescue nil
  FileUtils.rm "test/paperclip.db" rescue nil
end

spec = Gem::Specification.new do |s| 
  s.rubygems_version  = "1.2.0"
  s.name              = "paperclip"
  s.version           = Paperclip::VERSION
  s.author            = "Jon Yurek"
  s.email             = "jyurek@thoughtbot.com"
  s.homepage          = "http://www.thoughtbot.com/"
  s.platform          = Gem::Platform::RUBY
  s.summary           = "File attachments as attributes for ActiveRecord"
  s.files             = FileList["README",
                                 "LICENSE",
                                 "Rakefile",
                                 "init.rb",
                                 "{generators,lib,tasks,test}/**/*"].to_a
  s.require_path      = "lib"
  s.test_files        = FileList["test/**/test_*.rb"].to_a
  s.rubyforge_project = "paperclip"
  s.has_rdoc          = true
  s.extra_rdoc_files  = ["README"]
  s.rdoc_options << '--line-numbers' << '--inline-source'
  s.requirements << "ImageMagick"
  s.add_runtime_dependency 'right_aws'
  s.add_development_dependency 'Shoulda'
  s.add_development_dependency 'mocha'
end
 
Rake::GemPackageTask.new(spec) do |pkg| 
  pkg.need_tar = true 
end 

desc "Release new version"
task :release => [:test, :sync_docs, :gem] do
  require 'rubygems'
  require 'rubyforge'
  r = RubyForge.new
  r.login
  r.add_release spec.rubyforge_project,
                spec.name,
                spec.version,
                File.join("pkg", "#{spec.name}-#{spec.version}.gem")
end
