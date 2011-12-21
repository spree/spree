require 'rails/generators'
require 'highline/import'
require 'bundler'
require 'bundler/cli'

module Spree
  class InstallGenerator < Rails::Generators::Base
    argument :after_bundle_only, :type => :string, :default => "false"

    class_option :auto_accept, :type => :boolean, :default => false, :aliases => '-A', :desc => "Answer yes to all prompts"
    class_option :skip_install_data, :type => :boolean, :default => false
    class_option :lib_name, :default => 'spree'
    class_option :test_app, :type => :boolean, :default => false

    def self.source_paths
      paths = self.superclass.source_paths
      paths << File.expand_path('../templates', "../../#{__FILE__}")
      paths << File.expand_path('../templates', "../#{__FILE__}")
      paths << File.expand_path('../templates', __FILE__)
      paths.flatten
    end

    def add_files
      template 'config/initializers/spree.rb', 'config/initializers/spree.rb'
    end

    def config_spree_yml
      create_file "config/spree.yml" do
        settings = { 'version' => Spree.version }

        settings.to_yaml
      end
    end

    def remove_unneeded_files
      remove_file "public/index.html"
    end

    def additional_tweaks
      return unless File.exists? 'public/robots.txt'
      append_file "public/robots.txt", <<-ROBOTS
User-agent: *
Disallow: /checkouts
Disallow: /orders
Disallow: /countries
Disallow: /line_items
Disallow: /password_resets
Disallow: /states
Disallow: /user_sessions
Disallow: /users
      ROBOTS
    end

    def create_overrides_directory
      empty_directory "app/overrides"
    end

    def configure_application
      application <<-APP

    config.to_prepare do
      # Load application's model / class decorators
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end

      # Load application's view overrides
      Dir.glob(File.join(File.dirname(__FILE__), "../app/overrides/*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end
      APP

      append_file "config/environment.rb", "\nActiveRecord::Base.include_root_in_json = true\n"
    end

    def install_gems
      return if options[:test_app]
      gems = {}

      if options[:auto_accept] || agree('Would you like to install the default blue theme? (y/n)')
        gems['spree_blue_theme'] = { :git => 'git@github.com:spree/spree_blue_theme.git',
                                     :ref => '07aea41ecae6948573c4830fcd7dbca11a8c220f' }
      end

      unless gems.empty?
        gems.each do |name, options|
          gem name, options
        end
        bundle_command :update
      end

    end

    def include_seed_data
      append_file "db/seeds.rb", <<-SEEDS
\n
Spree::Core::Engine.load_seed if defined?(Spree::Core)
Spree::Auth::Engine.load_seed if defined?(Spree::Auth)
      SEEDS
    end

    def install_migrations
      puts "Copying migrations..."
      silence_stream(STDOUT) do
        silence_warnings { rake 'railties:install:migrations' }
      end
    end

    def run_migrations
      unless options[:skip_install_data]
        unless options[:auto_accept]
          res = agree('Would you like to run migrations? (y/n)')
        end
        if res || options[:auto_accept]
          puts "Running migrations"
          rake('db:migrate')
        else
          @migrations_skipped = true
          puts "Skipping rake db:migrate, don't forget to run it!"
        end
      end
    end

    def populate_seed_data
      unless options[:skip_install_data]
        unless options[:auto_accept] || @migrations_skipped
          res = agree('Would you like to load the seed data? (y/n)')
        end
        if res || options[:auto_accept]
          puts "Loading seed data"
          rake('db:seed AUTO_ACCEPT=true')
        else
          puts "Skipping rake db:seed."
        end
      end
    end

    def load_sample_data
      unless options[:skip_install_data]
        unless options[:auto_accept] || @migrations_skipped
          res = agree('Would you like to load sample data? (y/n)')
        end
        if res || options[:auto_accept]
          puts "Loading sample data"
          rake('spree_sample:load')
        else
          puts "Skipping loading sample data. You can always run this later with rake spree_sample:load."
        end
      end
    end

    def notify_about_routes
      insert_into_file File.join('config', 'routes.rb'), :after => "Application.routes.draw do\n" do
        "  # Mount Spree's routes\n  mount Spree::Core::Engine, :at => '/'\n"
      end

      unless options[:quiet]
        puts "*" * 50
        puts "We added the following line to your application's config/routes.rb file:"
        puts " "
        puts "    mount Spree::Core::Engine, :at => '/'"
      end
    end

    private

    # Copied from https://github.com/rails/rails/blob/b1ceffd7b224c397d8ba5344b9c1438dd62f8325/railties/lib/rails/generators/app_base.rb#L189
    def bundle_command(command)
      say_status :run, "bundle #{command}"
      Bundler::CLI.new.send(command)
    end

  end
end
