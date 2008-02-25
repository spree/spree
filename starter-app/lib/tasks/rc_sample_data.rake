namespace :rc do
  desc "Populates store with sample products"
  task :sample_data => :environment do
    require 'active_record/fixtures'
    require 'custom_fixtures'
    require 'find'

    # load initial database fixtures (in db/sample/*.yml) into the current environment's database
    ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
    Dir.glob(File.join(RAILS_ROOT, 'db', 'sample', '*.{yml,csv}')).each do |fixture_file|
      Fixtures.create_fixtures('db/sample', File.basename(fixture_file, '.*'))
    end
    
    # make product images available to the app
    target = "#{RAILS_ROOT}/public/images/products/"
    source = "#{RAILS_ROOT}/lib/tasks/sample/products/"
    
    Find.find(source) do |f|
      # omit hidden directories (SVN, etc.)
      if File.basename(f) =~ /^[.]/
        Find.prune 
        next
      end

      src_path = source + f.sub(source, '')
      target_path = target + f.sub(source, '')

      if File.directory?(f)
        FileUtils.mkdir_p target_path
      else
        FileUtils.cp src_path, target_path
      end
    end

    puts "Sample products have been loaded into to the store"
  end
end

