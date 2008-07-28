namespace :spree do
  namespace :extensions do
    namespace :tax_calculator do
      
      desc "Copies public assets of the Tax Calculator to the instance public/ directory."
      task :update => :environment do
        is_svn_or_dir = proc {|path| path =~ /\.svn/ || File.directory?(path) }
        Dir[TaxCalculatorExtension.root + "/public/**/*"].reject(&is_svn_or_dir).each do |file|
          path = file.sub(TaxCalculatorExtension.root, '')
          directory = File.dirname(path)
          puts "Copying #{path}..."
          mkdir_p RAILS_ROOT + directory
          cp file, RAILS_ROOT + path
        end
      end  
    end
  end
end
