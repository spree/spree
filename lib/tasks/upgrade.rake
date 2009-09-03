namespace :spree do
  desc "Assistance for upgrading an existing Spree deployment.  WARNING: Will replace certain javascript and stylesheet assets, but the replaced files are saved with a ~ suffix."
  task :upgrade => :environment do
    # remove defunct file
    sl = "#{RAILS_ROOT}/config/initializers/searchlogic.rb"; File.rename(sl, sl + '~') if File.exist?(sl)

    # move session_store to new place in site initializer
    site_extension_dir = "#{RAILS_ROOT}/vendor/extensions/site/"
    session_store_file = "config/initializers/session_store.rb"
    if File.exist?(site_extension_dir) && File.exist?("#{RAILS_ROOT}/#{session_store_file}")
      FileUtils.mkdir(site_extension_dir + "/config") rescue ''
      FileUtils.mkdir(site_extension_dir + "/config/initializers") rescue ''
      File.rename("#{RAILS_ROOT}/#{session_store_file}", "#{site_extension_dir}/#{session_store_file}")
    end

    # copy the "infrastructure" files 
    items = [ "/public/javascripts", 
              "/public/stylesheets", 
              "/public/images", 
              "/config/initializers", 
              "/config/spree_permissions.yml", 
              "/config/environment.rb", 
              "/config/boot.rb" ]
    items.each do |item|
      Spree::FileUtilz.mirror_with_backup(SPREE_ROOT + item, RAILS_ROOT + item)
    end

    # discard copied session_store
    if File.exist?(site_extension_dir)
      FileUtils.rm("#{RAILS_ROOT}/#{session_store_file}")
    end
  end
end  

