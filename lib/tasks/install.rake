namespace :spree do
  desc "Copies all migrations and assets (NOTE: This will be obsolete with Rails 3.1)"
  task :install do
    Rake::Task['spree:install:migrations'].invoke
    Rake::Task['spree:install:assets'].invoke
  end

  namespace :install do

    desc "Copies all migrations (NOTE: This will be obsolete with Rails 3.1)"
    task :migrations do
      Rake::Task['spree_core:install:migrations'].invoke
      Rake::Task['spree_auth:install:migrations'].invoke
      Rake::Task['spree_api:install:migrations'].invoke
      Rake::Task['spree_dash:install:migrations'].invoke
      Rake::Task['spree_promo:install:migrations'].invoke
    end

    desc "Copies all assets (NOTE: This will be obsolete with Rails 3.1)"
    task :assets do
      Rake::Task['spree_core:install:assets'].invoke
      Rake::Task['spree_auth:install:assets'].invoke
      Rake::Task['spree_api:install:assets'].invoke
      Rake::Task['spree_dash:install:assets'].invoke
      Rake::Task['spree_promo:install:assets'].invoke
    end

  end
end
