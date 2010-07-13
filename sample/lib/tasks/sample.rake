namespace :spree do
  desc "Synchronize public assets, migrations, seed and sample data from the Spree gems"
  task :sync do
    sample_dir = File.join(File.dirname(__FILE__), '..', '..', 'db', 'sample')
    assets_dir = File.join(File.dirname(__FILE__), '..', '..', 'assets')
    puts "Mirror: #{sample_dir}"
    Spree::FileUtilz.mirror_with_backup(sample_dir, File.join(Rails.root, 'db', 'sample'))
    puts "Mirror: #{assets_dir}"
    Spree::FileUtilz.mirror_with_backup(assets_dir, File.join(Rails.root, 'db', 'sample', 'assets'))
  end
end