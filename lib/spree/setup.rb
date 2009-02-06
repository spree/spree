#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################
require "highline"
require 'custom_fixtures'
require 'find'

module Spree
  class Setup
  
    class << self
      def bootstrap(config)
        setup = new
        setup.bootstrap(config)
        setup
      end  
      def create_admin_user
        raise "Cannot create a second admin user." unless User.count == 0
        new.create_admin_user
      end
    end
    
    attr_accessor :config
    
    def bootstrap(config)    
      # make sure the product images directory exists
      FileUtils.mkdir_p "#{RAILS_ROOT}/public/images/products/"
      
      @config = config
      @admin = create_admin_user(config[:admin_password], config[:admin_email])
      load_sample_data if sample_data?
      announce "Finished.\n\n"
    end

    def create_admin_user(password=nil, email=nil)
      unless email and password
        announce "Create the admin user (press enter for defaults)."
        #name = prompt_for_admin_name unless name
        email = prompt_for_admin_email unless email
        password = prompt_for_admin_password unless password
      end
      attributes = {
        :password => password,
        :password_confirmation => password,
        :email => email
      }
      admin = User.create(attributes)
      
      # create an admin role and and assign the admin user to that role
      role = Role.create(:name => 'admin')
      admin.roles << role
      admin.save      
      admin      
    end
    
    # Uses a special set of fixtures to load sample data
    def load_sample_data
      # load initial database fixtures (in db/sample/*.yml) into the current environment's database
      ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
      Dir.glob(File.join(SPREE_ROOT, "db", 'sample', '*.{yml,csv}')).each do |fixture_file|
        Fixtures.create_fixtures("#{SPREE_ROOT}/db/sample", File.basename(fixture_file, '.*'))
      end

      # make product images available to the app
      target = "#{RAILS_ROOT}/public/assets/products/"
      source = "#{SPREE_ROOT}/lib/tasks/sample/products/"

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

      announce "Sample products have been loaded into to the store"
    end
         
    private
      
      def prompt_for_admin_password
        password = ask('Password [spree]: ', String) do |q|
          q.echo = false
          q.validate = /^(|.{5,40})$/
          q.responses[:not_valid] = "Invalid password. Must be at least 5 characters long."
          q.whitespace = :strip
        end
        password = "spree" if password.blank?
        password
      end
      
      def prompt_for_admin_email
        email = ask('Email [spree@example.com]: ', String) do |q|
          q.echo = false
          q.whitespace = :strip
        end
        email = "spree@example.com" if email.blank?
        email
      end  
      
      # ask user if we should generate some sample data
      def sample_data?
        return true if ENV['AUTO_ACCEPT']
        sample = ask('Load Sample Data? [y]: ', String) do |q|
          q.echo = false
          q.whitespace = :strip
        end
        sample == "" or sample == "y" or sample == "yes" or sample == "true"
      end          

      def announce(string)
        puts "\n#{string}"
      end
  end
end