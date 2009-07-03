require 'activerecord'              

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
      Spree::Setup.create_admin_user      
    end
  end
  
  desc 'Create the database, load the schema, and initialize with the seed data'  
  task :setup => [ 'db:create', 'db:schema:load', 'db:seed' ]  
       
  desc 'Load the seed data from db/seeds.rb'  
  task :seed => :environment do  
    seed_file = File.join(SPREE_ROOT, 'db', 'seeds.rb')  
    load(seed_file) if File.exist?(seed_file)  
  end

  desc 'Load the sample fixture data from db/sample'  
  task :sample => :environment do  
    require 'spree/setup'
    Spree::Setup.load_sample_data
  end
    
  desc "Bootstrap your database for Spree."
  task :bootstrap  => :environment do
    require 'highline/import'       
    require 'authlogic'     

    # remigrate unless production mode (as saftey check)
    if %w[demo development test].include? RAILS_ENV 
      if ENV['AUTO_ACCEPT'] or agree("This task will destroy any data in the database. Are you sure you want to \ncontinue? [yn] ")
        ENV['SKIP_NAG'] = 'yes'
        Rake::Task["db:remigrate"].invoke
      else
        say "Task cancelled."
        exit
      end
    else 
      say "NOTE: Bootstrap in production mode will not drop database before migration"
      Rake::Task["db:migrate"].invoke
    end
    
    require 'spree/setup'
    
    attributes = {}
    if ENV['AUTO_ACCEPT']
      attributes = {
        :admin_password => "spree",
        :admin_email => "spree@example.com"          
      }
    end
    
    Spree::Setup.bootstrap attributes
  end
end
