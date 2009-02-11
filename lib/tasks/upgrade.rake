namespace :spree do
  desc "Assistance for upgrading an existing Spree deployment.  WARNING: Will replace certain javascript and stylesheet assets."
  task :upgrade => :environment do
                                   
    Spree::FileUtilz.mirror_files "#{SPREE_ROOT}/public/javascripts", "#{RAILS_ROOT}/public/javascripts"
    Spree::FileUtilz.mirror_files "#{SPREE_ROOT}/public/stylesheets", "#{RAILS_ROOT}/public/stylesheets"
    Spree::FileUtilz.mirror_files "#{SPREE_ROOT}/public/images", "#{RAILS_ROOT}/public/images"
  end
end  

