# I think this is the one that should be moved to the extension Rakefile template

# In rails 1.2, plugins aren't available in the path until they're loaded.
# Check to see if the rspec plugin is installed first and require
# it if it is.  If not, use the gem version.

# Determine where the RSpec plugin is by loading the boot
unless defined? SPREE_ROOT
  ENV["RAILS_ENV"] = "test"
  case
  when ENV["SPREE_ENV_FILE"]
    require File.dirname(ENV["SPREE_ENV_FILE"]) + "/boot"
  when File.dirname(__FILE__) =~ %r{vendor/SPREE/vendor/extensions}
    require "#{File.expand_path(File.dirname(__FILE__) + "/../../../../../")}/config/boot"
  else
    require "#{File.expand_path(File.dirname(__FILE__) + "/../../../")}/config/boot"
  end
end

require 'rake'
require 'rake/rdoctask'
require 'rake/testtask'

rspec_base = File.expand_path(SPREE_ROOT + '/vendor/plugins/rspec/lib')
$LOAD_PATH.unshift(rspec_base) if File.exist?(rspec_base)
require 'spec/rake/spectask'
# require 'spec/translator'

# Cleanup the SPREE_ROOT constant so specs will load the environment
Object.send(:remove_const, :SPREE_ROOT)

extension_root = File.expand_path(File.dirname(__FILE__))

task :default => :spec
task :stats => "spec:statsetup"

desc "Run all specs in spec directory"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_opts = ['--options', "\"#{extension_root}/spec/spec.opts\""]
  t.spec_files = FileList['spec/**/*_spec.rb']
end

namespace :spec do
  desc "Run all specs in spec directory with RCov"
  Spec::Rake::SpecTask.new(:rcov) do |t|
    t.spec_opts = ['--options', "\"#{extension_root}/spec/spec.opts\""]
    t.spec_files = FileList['spec/**/*_spec.rb']
    t.rcov = true
    t.rcov_opts = ['--exclude', 'spec', '--rails']
  end
  
  desc "Print Specdoc for all specs"
  Spec::Rake::SpecTask.new(:doc) do |t|
    t.spec_opts = ["--format", "specdoc", "--dry-run"]
    t.spec_files = FileList['spec/**/*_spec.rb']
  end

  [:models, :controllers, :views, :helpers].each do |sub|
    desc "Run the specs under spec/#{sub}"
    Spec::Rake::SpecTask.new(sub) do |t|
      t.spec_opts = ['--options', "\"#{extension_root}/spec/spec.opts\""]
      t.spec_files = FileList["spec/#{sub}/**/*_spec.rb"]
    end
  end
  
  # Hopefully no one has written their extensions in pre-0.9 style
  # desc "Translate specs from pre-0.9 to 0.9 style"
  # task :translate do
  #   translator = ::Spec::Translator.new
  #   dir = RAILS_ROOT + '/spec'
  #   translator.translate(dir, dir)
  # end

  # Setup specs for stats
  task :statsetup do
    require 'code_statistics'
    ::STATS_DIRECTORIES << %w(Model\ specs spec/models)
    ::STATS_DIRECTORIES << %w(View\ specs spec/views)
    ::STATS_DIRECTORIES << %w(Controller\ specs spec/controllers)
    ::STATS_DIRECTORIES << %w(Helper\ specs spec/views)
    ::CodeStatistics::TEST_TYPES << "Model specs"
    ::CodeStatistics::TEST_TYPES << "View specs"
    ::CodeStatistics::TEST_TYPES << "Controller specs"
    ::CodeStatistics::TEST_TYPES << "Helper specs"
    ::STATS_DIRECTORIES.delete_if {|a| a[0] =~ /test/}
  end

  namespace :db do
    namespace :fixtures do
      desc "Load fixtures (from spec/fixtures) into the current environment's database.  Load specific fixtures using FIXTURES=x,y"
      task :load => :environment do
        require 'active_record/fixtures'
        ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
        (ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : Dir.glob(File.join(RAILS_ROOT, 'spec', 'fixtures', '*.{yml,csv}'))).each do |fixture_file|
          Fixtures.create_fixtures('spec/fixtures', File.basename(fixture_file, '.*'))
        end
      end
    end
  end
end

desc 'Generate documentation for the localization extension.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'LocalizationExtension'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

# For extensions that are in transition
desc 'Test the localization extension.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

# Load any custom rakefiles for extension
Dir[File.dirname(__FILE__) + '/tasks/*.rake'].sort.each { |f| require f }