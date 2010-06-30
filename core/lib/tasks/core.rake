require 'active_record'
require 'custom_fixtures'

namespace :spree do
  desc "Synchronize public assets, migrations, seed and sample data from the Spree gems"
  task :sync do
    public_dir = File.join(File.dirname(__FILE__), '..', '..', 'public')
    migration_dir = File.join(File.dirname(__FILE__), '..', '..', 'db', 'migrate')
    default_dir = File.join(File.dirname(__FILE__), '..', '..', 'db', 'default')
    puts "Mirror: #{public_dir}"
    Spree::FileUtilz.mirror_with_backup(public_dir, File.join(Rails.root, 'public'))
    puts "Mirror: #{migration_dir}"
    Spree::FileUtilz.mirror_with_backup(migration_dir, File.join(Rails.root, 'db', 'migrate'))
    puts "Mirror: #{default_dir}"
    Spree::FileUtilz.mirror_with_backup(default_dir, File.join(Rails.root, 'db', 'default'))
  end
end

namespace :db do
  desc "Loads a specified fixture using rake db:load_file[filename.rb]"
  task :load_file , [:file] => :environment do |t , args|
    file = args.file
    ext = File.extname file
    if ext == ".csv" or ext == ".yml"
      puts "loading fixture " + file
      Fixtures.create_fixtures(File.dirname(file) , File.basename(file, '.*') )
    else
      if File.exists? file
        puts "loading ruby    " + file
        require file
      end
    end
  end

  desc "Loads fixtures from the the dir you specify using rake db:load_dir[loadfrom]"
  task :load_dir , [:dir] => :environment do |t , args|
    dir = args.dir
    fixtures = ActiveSupport::OrderedHash.new
    ruby_files = ActiveSupport::OrderedHash.new
    Dir.glob(File.join(Rails.root, "db", dir , '*.{yml,csv,rb}')).each do |fixture_file|
      ext = File.extname fixture_file
      if ext == ".rb"
        ruby_files[File.basename(fixture_file, '.*')]  = fixture_file
      else
        fixtures[File.basename(fixture_file, '.*')]  = fixture_file
      end
    end
    fixtures.sort.each do |fixture , fixture_file|
      # an invoke will only execute the task once
      Rake::Task["db:load_file"].execute( Rake::TaskArguments.new([:file], [fixture_file]) )
    end
    ruby_files.sort.each do |fixture , ruby_file|
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

  desc "Bootstrap is: migrating, loading defaults, sample data and seeding (for all extensions) invoking create_admin and load_products tasks"
  task :bootstrap  do
    require 'highline/import'
    require 'authlogic'

    # remigrate unless production mode (as saftey check)
    if %w[demo development test].include? Rails.env
      if ENV['AUTO_ACCEPT'] or agree("This task will destroy any data in the database. Are you sure you want to \ncontinue? [y/n] ")
        ENV['SKIP_NAG'] = 'yes'
        Rake::Task["db:remigrate"].invoke
      else
        say "Task cancelled, exiting."
        exit
      end
    else
      say "NOTE: Bootstrap in production mode will not drop database before migration"
      Rake::Task["db:migrate"].invoke
    end

    load_defaults  = Country.count == 0
    unless load_defaults    # ask if there are already Countries => default data hass been loaded
      load_defaults = agree('Countries present, load sample data anyways? [y/n]: ')
    end
    Rake::Task["db:seed"].invoke if load_defaults

    if Rails.env == 'production' and Product.count > 0
      load_sample = agree("WARNING: In Production and products exist in database, load sample data anyways? [y/n]:" )
    else
      load_sample = true if ENV['AUTO_ACCEPT']
      load_sample = agree('Load Sample Data? [y/n]: ') unless load_sample
    end
    Rake::Task["db:sample"].invoke if load_sample

    puts "Bootstrap Complete.\n\n"
  end

end