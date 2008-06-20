namespace :spree do
  namespace :extensions do
    namespace :payment_gateway do
      
      desc "Runs the migration of the Payment Gateway extension"
      task :migrate => :environment do
        require 'spree/extension_migrator'
        if ENV["VERSION"]
          PaymentGatewayExtension.migrator.migrate(ENV["VERSION"].to_i)
        else
          PaymentGatewayExtension.migrator.migrate
        end
      end
      
      desc "Copies public assets of the Payment Gateway to the instance public/ directory."
      task :update => :environment do
        is_svn_or_dir = proc {|path| path =~ /\.svn/ || File.directory?(path) }
        Dir[PaymentGatewayExtension.root + "/public/**/*"].reject(&is_svn_or_dir).each do |file|
          path = file.sub(PaymentGatewayExtension.root, '')
          directory = File.dirname(path)
          puts "Copying #{path}..."
          mkdir_p RAILS_ROOT + directory
          cp file, RAILS_ROOT + path
        end
      end  
    end
  end
end
