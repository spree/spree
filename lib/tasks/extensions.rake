require 'rake/testtask'

namespace :db do
  namespace :migrate do
    desc "Run all Spree extension migrations"
    task :extensions => :environment do
      require 'spree/extension_migrator'
      Spree::ExtensionMigrator.migrate_extensions
    end
  end

  namespace :remigrate do
    desc "Migrate down and back up all Spree extension migrations"
    task :extensions => :environment do
      require 'highline/import'
      # skip the prompt if we're here as the result of db:bootstrap
      if ENV['SKIP_NAG'] or agree("This task will destroy any data stored by extensions in the database. Are you sure you want to \ncontinue? [yn] ")
        ENV['SKIP_NAG'] = 'yes'
        Rake::Task['db:migrate:extensions:zero'].invoke
        Rake::Task['db:migrate:extensions'].invoke
      end
    end
  end
end

namespace :db do
  namespace :migrate do
    namespace :extensions do
      desc "Migrate all Spree extensions back down to VERSION=0."
      task :zero => :environment do
        begin 
          problem = false
          # this will cause an exception if there is no schema info 
          ActiveRecord::Migrator.current_version
        rescue
          # ignore problems - presumably schema is just missing b/c this is the first time running bootstrap
          problem = true
        end
        
        unless problem
          require 'highline/import'
          # skip the prompt if we're here as the result of db:bootstrap
          if ENV['SKIP_NAG'] or agree("This task will destroy any data stored by extensions in the database. Are you sure you want to \ncontinue? [yn] ")
            require 'spree/extension_migrator'     
            Spree::Extension.descendants.map(&:migrator).each {|m| m.migrate(0) }
          end
        end
      end
    end
  end
end

namespace :test do
  desc "Runs tests on all available Spree extensions, pass EXT=extension_name to test a single extension"
  task :extensions => "db:test:prepare" do
    extension_roots = Spree::Extension.descendants.map(&:root)
    if ENV["EXT"]
      extension_roots = extension_roots.select {|x| /\/(\d+_)?#{ENV["EXT"]}$/ === x }
      if extension_roots.empty?
        puts "Sorry, that extension is not installed."
      end
    end
    extension_roots.each do |directory|
      if File.directory?(File.join(directory, 'test'))
        chdir directory do
          if RUBY_PLATFORM =~ /win32/
            system "rake.cmd test SPREE_ENV_FILE=#{RAILS_ROOT}/config/environment"
          else
            system "rake test SPREE_ENV_FILE=#{RAILS_ROOT}/config/environment"
          end
        end
      end
    end
  end
end

namespace :spec do
  desc "Runs specs on all available Spree extensions, pass EXT=extension_name to test a single extension"
  task :extensions => "db:test:prepare" do
    extension_roots = Spree::Extension.descendants.map(&:root)
    if ENV["EXT"]
      extension_roots = extension_roots.select {|x| /\/(\d+_)?#{ENV["EXT"]}$/ === x }
      if extension_roots.empty?
        puts "Sorry, that extension is not installed."
      end
    end
    extension_roots.each do |directory|
      if File.directory?(File.join(directory, 'spec'))
        chdir directory do
          if RUBY_PLATFORM =~ /win32/
            system "rake.cmd spec SPREE_ENV_FILE=#{RAILS_ROOT}/config/environment"
          else
            system "rake spec SPREE_ENV_FILE=#{RAILS_ROOT}/config/environment"
          end
        end
      end
    end
  end
end

# Load any custom rakefiles from extensions
[RAILS_ROOT, SPREE_ROOT].uniq.each do |root|
  Dir[root + '/vendor/extensions/*/lib/tasks/*.rake'].sort.each { |ext| load ext }
end