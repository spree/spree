namespace :spree do
  #RAILS3 TODO - add core rake tasks
  # desc "Fake rake task to do some things"
  task :sync do
    public_dir = File.join(File.dirname(__FILE__), '..', '..', 'public')
    puts "Mirroring files from: #{public_dir}"
    Spree::FileUtilz.mirror_files(public_dir, File.join(Rails.root, 'public'))
  end
end