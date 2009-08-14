namespace :spree do
  desc "Assistance for upgrading an existing Spree deployment.  WARNING: Will replace certain javascript and stylesheet assets."
  task :upgrade => :environment do
                                   
    Spree::FileUtilz.mirror_files "#{SPREE_ROOT}/public/javascripts", "#{RAILS_ROOT}/public/javascripts"
    Spree::FileUtilz.mirror_files "#{SPREE_ROOT}/public/stylesheets", "#{RAILS_ROOT}/public/stylesheets"
    Spree::FileUtilz.mirror_files "#{SPREE_ROOT}/public/images", "#{RAILS_ROOT}/public/images"
    Spree::FileUtilz.mirror_files "#{SPREE_ROOT}/config/initializers", "#{RAILS_ROOT}/config/initializers"
    FileUtils.cp("#{SPREE_ROOT}/config/spree_permissions.yml", "#{RAILS_ROOT}/config")
    FileUtils.cp("#{SPREE_ROOT}/config/routes.rb", "#{RAILS_ROOT}/config")
    FileUtils.cp("#{SPREE_ROOT}/config/boot.rb", "#{RAILS_ROOT}/config")    
    sl = "#{RAILS_ROOT}/config/initializers/searchlogic.rb"; File.rename(sl, sl + '~') if File.exist?(sl)
  end
end  

