namespace :spree do
  desc "Synchronize public assets, migrations, seed and sample data from the Spree gems"
  task :sync do
    migration_dir = File.join(File.dirname(__FILE__), '..', '..', 'db', 'migrate')
    puts "Mirror: #{migration_dir}"
    Spree::FileUtilz.mirror_with_backup(migration_dir, File.join(Rails.root, 'db', 'migrate'))
  end
end