#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################
require "highline"
require "forwardable"
require 'active_record/fixtures'
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
      load_default_tax_treatments
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
    
    # This is a temporary workaround.  Remove this once tax treatments are supported via extensions.
    def load_default_tax_treatments
      TaxTreatment.create(:name => "Non taxable")
      TaxTreatment.create(:name => "U.S. Sales Tax")
    end
    
    # Uses a special set of fixtures to load sample data
    def load_sample_data
      # load initial database fixtures (in db/sample/*.yml) into the current environment's database
      ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
      Dir.glob(File.join(SPREE_ROOT, 'db', 'sample', '*.{yml,csv}')).each do |fixture_file|
        Fixtures.create_fixtures('db/sample', File.basename(fixture_file, '.*'))
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
        sample == "y" or sample == "yes" or sample == "true"
      end          
=begin      
      def find_template_in_path(filename)
        [
          filename,
          "#{RADIANT_ROOT}/#{filename}",
          "#{RADIANT_ROOT}/db/templates/#{filename}",
          "#{RAILS_ROOT}/#{filename}",
          "#{RAILS_ROOT}/db/templates/#{filename}",
          "#{Dir.pwd}/#{filename}",
          "#{Dir.pwd}/db/templates/#{filename}",
        ].find { |name| File.file?(name) }
      end
      
      def find_and_load_templates(glob)
        templates = Dir[glob]
        templates.map! { |template| load_template_file(template) }
        templates.sort_by { |template| template['name'] }
      end
      
      def load_template_file(filename)
        YAML.load_file(filename)
      end
      
      def create_records(template)
        records = template['records']
        if records
          puts
          records.keys.each do |key|
            feedback "Creating #{key.to_s.underscore.humanize}" do
              model = model(key)
              model.reset_column_information
              record_pairs = order_by_id(records[key])
              step do
                record_pairs.each do |id, record|
                  model.new(record).save
                end
              end
            end
          end
        end
      end
      
      def model(model_name)
        model_name.to_s.singularize.constantize
      end
      
      def order_by_id(records)
        records.map { |name, record| [record['id'], record] }.sort { |a, b| a[0] <=> b[0] }
      end
      
      extend Forwardable
      def_delegators :terminal, :agree, :ask, :choose, :say
  
      def terminal
        @terminal ||= HighLine.new
      end
  
      def output
        terminal.instance_variable_get("@output")
      end
  
      def wrap(string)
        string = terminal.send(:wrap, string) unless terminal.wrap_at.nil?
        string
      end
  
      def print(string)
        output.print(wrap(string))
        output.flush
      end
  
      def puts(string = "\n")
        say string
      end
=end  
      def announce(string)
        puts "\n#{string}"
      end
=begin            
      def feedback(process, &block)
        print "#{process}..."
        if yield
          puts "OK"
          true
        else
          puts "FAILED"
          false
        end
      rescue Exception => e
        puts "FAILED"
        raise e
      end
      
      def step
        yield if block_given?
        print '.'
      end
=end   
  end
end