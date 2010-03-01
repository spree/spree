require 'active_record'              
require 'custom_fixtures'

namespace :db do
  desc "Migrate schema to version 0 and back up again. WARNING: Destroys all data in tables!!"
  task :remigrate => :environment do
    require 'highline/import'       
    
    if ENV['SKIP_NAG'] or ENV['OVERWRITE'].to_s.downcase == 'true' or agree("This task will destroy any data in the database. Are you sure you want to \ncontinue? [yn] ")

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
        
  namespace :admin do                       
    desc "Create admin username and password"
    task :create => :environment do
      require 'authlogic'     
      require "#{SPREE_ROOT}/db/sample/users.rb" 
    end
  end

  desc "Loading db/sample for spree and each extension"
  task :sample => :environment do   # an invoke will not execute the task after defaults has already executed it
    Rake::Task["db:load_dir"].execute( Rake::TaskArguments.new([:dir],  ["sample" ]) ) 
    puts "Sample data has been loaded"
  end

  desc "Loading file for spree and each extension where you specify dir by rake db:load_file[filename.rb]"
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

  desc "Dump a class to YML, give class name in square brackets, use rake -s for silent"
  task :dump , [:clazz]  => :environment do  |t , args|
    clazz = eval(args.clazz)
    objects = {}
    clazz.find( :all ).each do |obj|
      attributes = obj.attributes
      attributes.delete("created_at")   
      attributes.delete("updated_at")   
      name = attributes["name"] 
      unless name
        name = args.clazz 
        name = name +   "_" + attributes["id"].to_s if attributes["id"]
      end
      name = name.gsub( " " , "_")
      objects[name] = attributes
    end
    puts objects.to_yaml
  end

  desc 'Create the database, load the schema, and initialize with the seed data'  
  task :setup => [ 'db:create', 'db:schema:load', 'db:seed' ]         
    
  desc "Bootstrap is: migrating, loading defaults, sample data and seeding (for all extensions) invoking create_admin and load_products tasks"
  task :bootstrap  => :environment do
    require 'highline/import' 
    require 'authlogic'

    # remigrate unless production mode (as saftey check)
    if %w[demo development test].include? RAILS_ENV 
      if ENV['AUTO_ACCEPT'] or agree("This task will destroy any data in the database. Are you sure you want to \ncontinue? [yn] ")
        ENV['SKIP_NAG'] = 'yes'
        Rake::Task["db:remigrate"].invoke
        puts "remigrate"
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
      load_defaults = agree('Countries present, load sample data anyways? [y]: ')
    end
    Rake::Task["db:seed"].invoke if load_defaults
    
    if RAILS_ENV == 'production' and Product.count > 0
      load_sample = agree("WARNING: In Production and products exist in database, load sample data anyways? [y]:" )
    else
      load_sample = true if ENV['AUTO_ACCEPT'] 
      load_sample = agree('Load Sample Data? [y]: ') unless load_sample    
    end
    Rake::Task["db:sample"].invoke if load_sample

    puts "Bootstrap Complete.\n\n"
  end
end
