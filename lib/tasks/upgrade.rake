namespace :spree do
  desc "Assistance for upgrading an existing Spree deployment. (Deprecated)"
  task :upgrade => :environment do
    puts "This task has been deprecated.  Run 'spree --update' command using the newest gem instead."
  end
end  

