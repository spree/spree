#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################
namespace :db do
  desc "Migrate schema to version 0 and back up again. WARNING: Destroys all data in tables!!"
  task :remigrate => :environment do
    require 'highline/import'
    if ENV['OVERWRITE'].to_s.downcase == 'true' or agree("This task will destroy any data in the database. Are you sure you want to \ncontinue? [yn] ")
      
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
  task :bootstrap => :remigrate do
    require 'spree/setup'
    Spree::Setup.bootstrap(
      :admin_name => ENV['ADMIN_NAME'],
      :admin_username => ENV['ADMIN_USERNAME'],
      :admin_password => ENV['ADMIN_PASSWORD'],
      :admin_email => ENV['ADMIN_EMAIL'],
      :database_template => ENV['DATABASE_TEMPLATE']
    )
  end
end