require(File.join(File.dirname(__FILE__), 'config', 'boot'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails'

unless Rake::Task.task_defined? "db:sample"
  Dir["#{SPREE_ROOT}/lib/tasks/**/*.rake"].sort.each { |ext| load ext }
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "spree"
    s.summary = "Open Source E-Commerce for Ruby on Rails"
    s.description = "The most flexible commerce platform available - designed from the ground up to be as open and extensible as possible."
    s.email = "sean@railsdog.com"
    s.homepage = "http://github.com/railsdog/spree"
    s.authors = ["Sean Schofield"]
    s.add_dependency('treetop', '>= 1.4.2')
    s.bindir = 'bin'
    s.executables = ['spree']
    s.rubyforge_project = 'spree'
    s.version = Spree::Version
    s.add_dependency 'rake', '>= 0.7.1'
    s.add_dependency 'highline', '>= 1.4.0'
    s.add_dependency 'rails', '= 2.3.5'
    s.add_dependency 'rack', '>= 1.0.1'
    s.add_dependency 'activemerchant', '= 1.4.1'
    s.add_dependency 'activerecord-tableless', '>= 0.1.0'
    #s.add_dependency 'authlogic', '>=2.0.11'  (For some reason including authlogic causes bug - see #433)
    s.add_dependency 'calendar_date_select', '= 1.15' 
    s.add_dependency 'haml-edge', '>=2.1.37'
    s.add_dependency 'chronic', '>=0.2.3'
    s.add_dependency 'tlsmail', '= 0.0.1' 
    s.add_dependency 'rspec', '>= 1.2.0'
    s.add_dependency 'rspec-rails', '>= 1.2.0'
    s.add_dependency 'searchlogic', ">=2.3.5"
    s.has_rdoc = true
    rdoc_excludes = Dir["**"].reject { |f| !File.directory? f }
    rdoc_excludes.each do |e|
      s.rdoc_options << '--exclude' << e
    end     
    files = FileList['**/*']
    files.exclude '**/._*'
    files.exclude '**/*.rej'
    files.exclude 'cache/'
    files.exclude 'config/locomotive.yml'
    files.exclude 'config/lighttpd.conf'
    files.exclude 'config/mongrel_mimes.yml'
    files.exclude 'db/schema.db'
    files.exclude 'db/*.sqlite3'
    files.exclude 'db/*.sql'
    files.exclude /^doc/
    files.exclude 'log/*.log'
    files.exclude 'log/*.pid'
    files.exclude /^pkg/
    files.include 'public/.htaccess.example'
    files.exclude 'public/images/products'
    files.exclude 'public/assets/products'
    files.exclude 'spree.gemspec'
    files.exclude 'tmp/'
    files.exclude 'vendor/plugins/delegate_belongs_to/spec/app_root/log/*.log'
    files.exclude 'vendor/plugins/resource_controller/test/*'
    s.files = files.to_a
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install jeweler"
end