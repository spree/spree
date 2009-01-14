rspec_gem_dir = nil
Dir["#{RAILS_ROOT}/vendor/gems/*"].each do |subdir|
  rspec_gem_dir = subdir if subdir.gsub("#{RAILS_ROOT}/vendor/gems/","") =~ /^(\w+-)?rspec-(\d+)/ && File.exist?("#{subdir}/lib/spec/rake/spectask.rb")
end
rspec_plugin_dir = File.expand_path(File.dirname(__FILE__) + '/../../vendor/plugins/rspec')

if rspec_gem_dir && (test ?d, rspec_plugin_dir)
  raise "\n#{'*'*50}\nYou have rspec installed in both vendor/gems and vendor/plugins\nPlease pick one and dispose of the other.\n#{'*'*50}\n\n"
end

if rspec_gem_dir
  $LOAD_PATH.unshift("#{rspec_gem_dir}/lib") 
elsif File.exist?(rspec_plugin_dir)
  $LOAD_PATH.unshift("#{rspec_plugin_dir}/lib")
end

begin
  require 'spec/rake/spectask'
  Rake.application.instance_variable_get('@tasks').delete('default')

  spec_prereq = File.exist?(File.join(RAILS_ROOT, 'config', 'database.yml')) ? "db:test:prepare" : :noop
  task :noop do
  end

  task :default => :spec
  task :stats => "spec:statsetup"

  desc "Run all specs in spec directory (excluding plugin specs)"
  Spec::Rake::SpecTask.new(:spec => spec_prereq) do |t|
    t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
    t.spec_files = FileList['spec/**/*/*_spec.rb']
  end

  namespace :spec do
    desc "Run all specs in spec directory with RCov (excluding plugin specs)"
    Spec::Rake::SpecTask.new(:rcov) do |t|
      t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
      t.spec_files = FileList['spec/**/*/*_spec.rb']
      t.rcov = true
      t.rcov_opts = lambda do
        IO.readlines("#{RAILS_ROOT}/spec/rcov.opts").map {|l| l.chomp.split " "}.flatten
      end
    end

    desc "Print Specdoc for all specs (excluding plugin specs)"
    Spec::Rake::SpecTask.new(:doc) do |t|
      t.spec_opts = ["--format", "specdoc", "--dry-run"]
      t.spec_files = FileList['spec/**/*/*_spec.rb']
    end

    desc "Print Specdoc for all plugin examples"
    Spec::Rake::SpecTask.new(:plugin_doc) do |t|
      t.spec_opts = ["--format", "specdoc", "--dry-run"]
      t.spec_files = FileList['vendor/plugins/**/spec/**/*/*_spec.rb'].exclude('vendor/plugins/rspec/*')
    end

    [:models, :controllers, :views, :helpers, :lib].each do |sub|
      desc "Run the code examples in spec/#{sub}"
      Spec::Rake::SpecTask.new(sub => spec_prereq) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList["spec/#{sub}/**/*_spec.rb"]
      end
    end

    desc "Run the code examples in vendor/plugins (except RSpec's own)"
    Spec::Rake::SpecTask.new(:plugins => spec_prereq) do |t|
      t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
      t.spec_files = FileList['vendor/plugins/**/spec/**/*/*_spec.rb'].exclude('vendor/plugins/rspec/*').exclude("vendor/plugins/rspec-rails/*")
    end

    namespace :plugins do
      desc "Runs the examples for rspec_on_rails"
      Spec::Rake::SpecTask.new(:rspec_on_rails) do |t|
        t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
        t.spec_files = FileList['vendor/plugins/rspec-rails/spec/**/*/*_spec.rb']
      end
    end

    # Setup specs for stats
    task :statsetup do
      require 'code_statistics'
      ::STATS_DIRECTORIES << %w(Model\ specs spec/models) if File.exist?('spec/models')
      ::STATS_DIRECTORIES << %w(View\ specs spec/views) if File.exist?('spec/views')
      ::STATS_DIRECTORIES << %w(Controller\ specs spec/controllers) if File.exist?('spec/controllers')
      ::STATS_DIRECTORIES << %w(Helper\ specs spec/helpers) if File.exist?('spec/helpers')
      ::STATS_DIRECTORIES << %w(Library\ specs spec/lib) if File.exist?('spec/lib')
      ::CodeStatistics::TEST_TYPES << "Model specs" if File.exist?('spec/models')
      ::CodeStatistics::TEST_TYPES << "View specs" if File.exist?('spec/views')
      ::CodeStatistics::TEST_TYPES << "Controller specs" if File.exist?('spec/controllers')
      ::CodeStatistics::TEST_TYPES << "Helper specs" if File.exist?('spec/helpers')
      ::CodeStatistics::TEST_TYPES << "Library specs" if File.exist?('spec/lib')
      ::STATS_DIRECTORIES.delete_if {|a| a[0] =~ /test/}
    end

    namespace :db do
      namespace :fixtures do
        desc "Load fixtures (from spec/fixtures) into the current environment's database.  Load specific fixtures using FIXTURES=x,y. Load from subdirectory in test/fixtures using FIXTURES_DIR=z."
        task :load => :environment do
          ActiveRecord::Base.establish_connection(Rails.env)
          base_dir = File.join(Rails.root, 'spec', 'fixtures')
          fixtures_dir = ENV['FIXTURES_DIR'] ? File.join(base_dir, ENV['FIXTURES_DIR']) : base_dir
          
          (ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/).map {|f| File.join(fixtures_dir, f) } : Dir.glob(File.join(fixtures_dir, '*.{yml,csv}'))).each do |fixture_file|
            Fixtures.create_fixtures(File.dirname(fixture_file), File.basename(fixture_file, '.*'))
          end
        end
      end
    end

    namespace :server do
      daemonized_server_pid = File.expand_path("spec_server.pid", RAILS_ROOT + "/tmp")

      desc "start spec_server."
      task :start do
        if File.exist?(daemonized_server_pid)
          $stderr.puts "spec_server is already running."
        else
          $stderr.puts "Starting up spec server."
          system("ruby", "script/spec_server", "--daemon", "--pid", daemonized_server_pid)
        end
      end

      desc "stop spec_server."
      task :stop do
        unless File.exist?(daemonized_server_pid)
          $stderr.puts "No server running."
        else
          $stderr.puts "Shutting down spec_server."
          system("kill", "-s", "TERM", File.read(daemonized_server_pid).strip) && 
          File.delete(daemonized_server_pid)
        end
      end

      desc "reload spec_server."
      task :restart do
        unless File.exist?(daemonized_server_pid)
          $stderr.puts "No server running."
        else
          $stderr.puts "Reloading down spec_server."
          system("kill", "-s", "USR2", File.read(daemonized_server_pid).strip)
        end
      end
    end
  end
rescue MissingSourceFile
  # if rspec-rails is a configured gem, this will output helpful material and exit ...
  require File.expand_path(File.dirname(__FILE__) + "/../../config/environment")

  # ... otherwise, do this:
  raise <<-MSG

  You have rspec rake tasks installed in
  #{__FILE__},
  but rspec can not be found in vendor/gems, vendor/plugins or on the system.

MSG
end

