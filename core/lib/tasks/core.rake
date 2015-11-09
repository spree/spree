require 'active_record'

namespace :db do
  desc %q{Loads a specified fixture file:
use rake db:load_file[/absolute/path/to/sample/filename.rb]}

  task :load_file , [:file, :dir] => :environment do |t, args|
    file = Pathname.new(args.file)

    puts "loading ruby #{file}"
    require file
  end

  desc "Loads fixtures from the the dir you specify using rake db:load_dir[loadfrom]"
  task :load_dir , [:dir] => :environment do |t, args|
    dir = args.dir
    dir = File.join(Rails.root, "db", dir) if Pathname.new(dir).relative?

    ruby_files = {}
    Dir.glob(File.join(dir , '**/*.{rb}')).each do |fixture_file|
      ext = File.extname fixture_file
      ruby_files[File.basename(fixture_file, '.*')] = fixture_file
    end
    ruby_files.sort.each do |fixture , ruby_file|
      # If file is exists within application it takes precendence.
      if File.exists?(File.join(Rails.root, "db/default/spree", "#{fixture}.rb"))
        ruby_file = File.expand_path(File.join(Rails.root, "db/default/spree", "#{fixture}.rb"))
      end
      # an invoke will only execute the task once
      Rake::Task["db:load_file"].execute( Rake::TaskArguments.new([:file], [ruby_file]) )
    end
  end

  desc "Migrate schema to version 0 and back up again. WARNING: Destroys all data in tables!!"
  task :remigrate => :environment do
    require 'highline/import'

    if ENV['SKIP_NAG'] or ENV['OVERWRITE'].to_s.downcase == 'true' or agree("This task will destroy any data in the database. Are you sure you want to \ncontinue? [y/n] ")

      # Drop all tables
      ActiveRecord::Base.connection.tables.each { |t| ActiveRecord::Base.connection.drop_table t }

      # Migrate upward
      Rake::Task["db:migrate"].invoke

      # Dump the schema
      Rake::Task["db:schema:dump"].invoke
    else
      say "Task cancelled."
      exit
    end
  end
end
