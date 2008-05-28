#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################
namespace :db do
  desc "Migrate schema to version 0 and back up again. WARNING: Destroys all data in tables!!"
  task :remigrate => :environment do
    require 'highline/import'
    if ENV['SKIP_NAG'] or ENV['OVERWRITE'].to_s.downcase == 'true' or agree("This task will destroy any data in the database. Are you sure you want to \ncontinue? [yn] ")

      ENV['SKIP_NAG'] = 'yes'
      
      # Migrate downward
      ActiveRecord::Migrator.migrate("#{SPREE_ROOT}/db/migrate/", 0)
    
      # Migrate upward 
      Rake::Task["db:migrate"].invoke
      
      # Dump the schema
      Rake::Task["db:schema:dump"].invoke
    else
      say "Task cancelled."
      exit
    end
  end
  
  desc "Bootstrap your database for Spree."
  task :bootstrap  do
    require 'highline/import'
    if ENV['AUTO_ACCEPT'] or agree("This task will destroy any data in the database. Are you sure you want to \ncontinue? [yn] ")
      # Migrate downward
      ENV['SKIP_NAG'] = 'yes'
      Rake::Task["db:migrate:extensions:zero"].invoke
      ActiveRecord::Migrator.migrate("#{SPREE_ROOT}/db/migrate/", 0)

      # Migrate upward 
      ActiveRecord::Migrator.migrate("#{SPREE_ROOT}/db/migrate/")
      Rake::Task["db:migrate:extensions"].invoke    
    
      # Dump the schema
      Rake::Task["db:schema:dump"].invoke

      require 'spree/setup'
      
      attributes = {}
      if ENV['AUTO_ACCEPT']
        attributes = {
          :admin_name => "Administrator", 
          :admin_username => "admin",
          :admin_password => "spree",
          :admin_email => "admin@example.com"          
        }
      end
      
      Spree::Setup.bootstrap attributes
    else
      say "Task cancelled."
      exit
    end
  end
end