namespace :spree do
  namespace :extensions do
    namespace :language_chooser do

      desc "Install the language chooser files"
      task :install => :update do
      end
      
      desc "Copies public assets of the Language Chooser to the instance public/ directory."
      task :update => :environment do
        is_svn_or_dir = proc {|path| path =~ /\.svn/ || File.directory?(path) }
        Dir[LanguageChooserExtension.root + "/public/**/*"].reject(&is_svn_or_dir).each do |file|
          path = file.sub(LanguageChooserExtension.root, '')
          directory = File.dirname(path)
          puts "Copying #{path}..."
          mkdir_p RAILS_ROOT + directory
          cp file, RAILS_ROOT + path
        end
      end  
    end
  end
end
