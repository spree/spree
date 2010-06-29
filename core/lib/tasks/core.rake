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
    unless ENV['SKIP_CORE'] and dir == "sample"
      Dir.glob(File.join(Rails.root, "db", dir , '*.{yml,csv,rb}')).each do |fixture_file|
        ext = File.extname fixture_file
        if ext == ".rb"
          ruby_files[File.basename(fixture_file, '.*')]  = fixture_file
        else
          fixtures[File.basename(fixture_file, '.*')]  = fixture_file
        end
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
end