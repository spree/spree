namespace :db do
  desc "Bootstrap your database for Spree."
  task :bootstrap  => :environment do
    # load initial database fixtures (in db/sample/*.yml) into the current environment's database
    ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
    Dir.glob(File.join(ThemeDefaultExtension.root, "db", 'sample', '*.{yml,csv}')).each do |fixture_file|
      Fixtures.create_fixtures("#{ThemeDefaultExtension.root}/db/sample", File.basename(fixture_file, '.*'))
    end
  end
end

namespace :spree do
  namespace :extensions do
    namespace :theme_default do
      desc "Copies public assets of the Theme Default to the instance public/ directory."
      task :update => :environment do
        is_svn_git_or_dir = proc {|path| path =~ /\.svn/ || path =~ /\.git/ || File.directory?(path) }
        Dir[ThemeDefaultExtension.root + "/public/**/*"].reject(&is_svn_git_or_dir).each do |file|
          path = file.sub(ThemeDefaultExtension.root, '')
          directory = File.dirname(path)
          puts "Copying #{path}..."
          mkdir_p RAILS_ROOT + directory
          cp file, RAILS_ROOT + path
        end
      end  
    end
  end
end

namespace :spree do
  namespace :dev do
    desc "Compile the screen.less for theme_default before committing."
    task :less do
      require 'less'
      #less_files = "#{SPREE_ROOT}/vendor/extensions/theme_default/app/stylesheets/"
      #destination = "#{SPREE_ROOT}/vendor/extensions/theme_default/public/stylesheets/"
      
      source = "#{SPREE_ROOT}/vendor/extensions/theme_default/app/stylesheets/screen.less"
      destination = "#{SPREE_ROOT}/vendor/extensions/theme_default/public/stylesheets/screen.css"
      #stylesheets = Dir.entries(less_files)
      f = File.new(destination, File::CREAT|File::TRUNC|File::RDWR, 0644)
      f.write Less::Engine.new(File.new(source)).to_css

      
      # stylesheets.select{|s| File.extname(s) == ".less"}.each do |sheet|
      #   f = File.new("#{destination}#{File.basename(sheet, ".less")}.css", File::CREAT|File::TRUNC|File::RDWR, 0644)
      #     f.write Less::Engine.new(File.new(less_files + sheet)).to_css
      # end
    end
  end
end


