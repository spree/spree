namespace :spree do
  desc "Assistance for upgrading an existing Spree deployment.  WARNING: Will replace certain javascript and stylesheet assets, but the replaced files are saved with a ~ suffix."
  task :upgrade => :environment do
    sl = "#{RAILS_ROOT}/config/initializers/searchlogic.rb"; File.rename(sl, sl + '~') if File.exist?(sl)
    items = [ "/public/javascripts", 
              "/public/stylesheets", 
              "/public/images", 
              "/config/initializers", 
              "/config/spree_permissions.yml", 
              "/config/routes.rb", 
              "/config/boot.rb" ]
    items.each do |item|
      Spree::FileUtilz.mirror_with_backup("#{SPREE_ROOT}" + item, "#{RAILS_ROOT}" + item)
    end
  end
end  

