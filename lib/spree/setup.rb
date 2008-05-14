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
    end
    
    attr_accessor :config
    
    def bootstrap(config)    
      @config = config
      @admin = create_admin_user(config[:admin_name], config[:admin_username], config[:admin_password], config[:admin_email])
      load_sample_data if sample_data?
      announce "Finished.\n\n"
    end

    def create_admin_user(name, username, password, email)
      unless name and username and password
        announce "Create the admin user (press enter for defaults)."
        #name = prompt_for_admin_name unless name
        username = prompt_for_admin_username unless username
        password = prompt_for_admin_password unless password
        email = prompt_for_admin_email unless email
      end
      attributes = {
        #:name => name,
        :login => username,
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
      target = "#{RAILS_ROOT}/public/images/products/"
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
=begin      
      def prompt_for_admin_name
        username = ask('Name (Administrator): ', String) do |q|
          q.validate = /^.{0,100}$/
          q.responses[:not_valid] = "Invalid name. Must be at less than 100 characters long."
          q.whitespace = :strip
        end
        username = "Administrator" if username.blank?
        username
      end
=end      
      def prompt_for_admin_username
        username = ask('Username [admin]: ', String) do |q|
          q.validate = /^(|.{3,40})$/
          q.responses[:not_valid] = "Invalid username. Must be at least 3 characters long."
          q.whitespace = :strip
        end
        username = "admin" if username.blank?
        username
      end
      
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