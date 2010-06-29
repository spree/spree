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

namespace :db do
  desc "Loads sample data into the store"
  task :sample do   # an invoke will not execute the task after defaults has already executed it
    Rake::Task["db:load_dir"].invoke( "sample" )
    puts "Sample data has been loaded"
  end
end