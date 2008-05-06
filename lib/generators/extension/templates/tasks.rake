namespace :spree do
  namespace :extensions do
    namespace :<%= file_name %> do
      
      desc "Runs the migration of the <%= extension_name %> extension"
      task :migrate => :environment do
        require 'spree/extension_migrator'
        if ENV["VERSION"]
          <%= class_name %>.migrator.migrate(ENV["VERSION"].to_i)
        else
          <%= class_name %>.migrator.migrate
        end
      end
      
      desc "Copies public assets of the <%= extension_name %> to the instance public/ directory."
      task :update => :environment do
        is_svn_or_dir = proc {|path| path =~ /\.svn/ || File.directory?(path) }
        Dir[<%= class_name %>.root + "/public/**/*"].reject(&is_svn_or_dir).each do |file|
          path = file.sub(<%= class_name %>.root, '')
          directory = File.dirname(path)
          puts "Copying #{path}..."
          mkdir_p RAILS_ROOT + directory
          cp file, RAILS_ROOT + path
        end
      end  
    end
  end
end
