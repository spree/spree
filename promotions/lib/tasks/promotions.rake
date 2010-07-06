namespace :spree do
  desc "Synchronize public assets, migrations, seed and sample data from the Spree gems"
  task :sync do
    public_dir = File.join(File.dirname(__FILE__), '..', '..', 'public')
    migration_dir = File.join(File.dirname(__FILE__), '..', '..', 'db', 'migrate')
    puts "Mirror: #{public_dir}"
    Spree::FileUtilz.mirror_with_backup(public_dir, File.join(Rails.root, 'public'))
    puts "Mirror: #{migration_dir}"
    Spree::FileUtilz.mirror_with_backup(migration_dir, File.join(Rails.root, 'db', 'migrate'))
  end
end