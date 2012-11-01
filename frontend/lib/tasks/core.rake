require 'active_record'
require 'spree/core/custom_fixtures'

namespace :db do
  desc %q{Loads a specified fixture file:
For .yml/.csv use rake db:load_file[spree/filename.yml,/absolute/path/to/parent/]
For .rb       use rake db:load_file[/absolute/path/to/sample/filename.rb]}

  task :load_file , [:file, :dir] => :environment do |t, args|
    file = Pathname.new(args.file)

    if %w{.csv .yml}.include? file.extname
      puts "loading fixture #{Pathname.new(args.dir).join(file)}"
      Spree::Core::Fixtures.create_fixtures(args.dir, file.to_s.sub(file.extname, ""))
    elsif file.exist?
      puts "loading ruby #{file}"
      require file
    end
  end

  desc "Loads fixtures from the the dir you specify using rake db:load_dir[loadfrom]"
  task :load_dir , [:dir] => :environment do |t , args|
    dir = args.dir
    dir = File.join(Rails.root, "db", dir) if Pathname.new(dir).relative?

    fixtures = ActiveSupport::OrderedHash.new
    ruby_files = ActiveSupport::OrderedHash.new
    Dir.glob(File.join(dir , '**/*.{yml,csv,rb}')).each do |fixture_file|
      ext = File.extname fixture_file
      if ext == ".rb"
        ruby_files[File.basename(fixture_file, '.*')] = fixture_file
      else
        fixtures[fixture_file.sub(dir, "")[1..-1]] = fixture_file
      end
    end
    fixtures.sort.each do |relative_path , fixture_file|
      # an invoke will only execute the task once
      Rake::Task["db:load_file"].execute( Rake::TaskArguments.new([:file, :dir], [relative_path, dir]) )
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

  desc "Bootstrap is: migrating, loading defaults, sample data and seeding (for all extensions) and load_products tasks"
  task :bootstrap  do
    require 'highline/import'

    # remigrate unless production mode (as saftey check)
    if %w[demo development test].include? Rails.env
      if ENV['AUTO_ACCEPT'] or agree("This task will destroy any data in the database. Are you sure you want to \ncontinue? [y/n] ")
        ENV['SKIP_NAG'] = 'yes'
        Rake::Task["db:create"].invoke
        Rake::Task["db:remigrate"].invoke
      else
        say "Task cancelled, exiting."
        exit
      end
    else
      say "NOTE: Bootstrap in production mode will not drop database before migration"
      Rake::Task["db:migrate"].invoke
    end

    ActiveRecord::Base.send(:subclasses).each do |model|
      model.reset_column_information
    end

    load_defaults  = Spree::Country.count == 0
    unless load_defaults    # ask if there are already Countries => default data hass been loaded
      load_defaults = agree('Countries present, load sample data anyways? [y/n]: ')
    end
    if load_defaults
      Rake::Task["db:seed"].invoke
    end

    if Rails.env.production? and Spree::Product.count > 0
      load_sample = agree("WARNING: In Production and products exist in database, load sample data anyways? [y/n]:" )
    else
      load_sample = true if ENV['AUTO_ACCEPT']
      load_sample = agree('Load Sample Data? [y/n]: ') unless load_sample
    end

    if load_sample
      #prevent errors for missing attributes (since rails 3.1 upgrade)

      Rake::Task["spree_sample:load"].invoke
    end

    puts "Bootstrap Complete.\n\n"
  end

end
