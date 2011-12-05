require 'ffaker'

namespace :spree_sample do
  desc "Loads sample data"
  task :load do
    sample_path = File.join(File.dirname(__FILE__), '..', '..', 'db', 'sample')

    Rake::Task['db:load_dir'].reenable
    Rake::Task["db:load_dir"].invoke( sample_path )
  end
end
