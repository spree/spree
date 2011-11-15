require 'rails/generators'
require 'highline/import'

module Spree
  class InstallGenerator < Rails::Generators::Base
    argument :after_bundle_only, :type => :string, :default => "false"

    class_option :auto_accept, :type => :boolean, :default => false, :aliases => '-A', :desc => "Answer yes to all prompts"
    class_option :skip_install_data, :type => :boolean, :default => false
    class_option :lib_name, :default => 'spree'
    attr :lib_name
    attr :auto_accept
    attr :skip_install_data
    attr :test_app

    def self.source_paths
      paths = self.superclass.source_paths
      paths << File.expand_path('../templates', "../../#{__FILE__}")
      paths << File.expand_path('../templates', "../#{__FILE__}")
      paths << File.expand_path('../templates', __FILE__)
      paths.flatten
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
      @lib_name = options[:lib_name]

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

    def setup_assets
      remove_file "app/assets/javascripts/application.js"
      remove_file "app/assets/stylesheets/application.css"
      remove_file "app/assets/images/rails.png"

      %w{javascripts stylesheets images}.each do |path|
        empty_directory "app/assets/#{path}/store"
        empty_directory "app/assets/#{path}/admin"
      end

      template "app/assets/javascripts/store/all.js"
      template "app/assets/javascripts/admin/all.js"
      template "app/assets/stylesheets/store/all.css"
      template "app/assets/stylesheets/admin/all.css"
    end

    def create_overrides_directory
      empty_directory "app/overrides"
    end

    def configure_application
      application <<-APP
    config.middleware.use "Spree::Core::Middleware::SeoAssist"
    config.middleware.use "Spree::Core::Middleware::RedirectLegacyProductUrl"

    config.to_prepare do
      #loads application's model / class decorators
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end
      APP

      append_file "config/environment.rb", "\nActiveRecord::Base.include_root_in_json = true\n"
    end

    def include_seed_data
      append_file "db/seeds.rb", <<-SEEDS
\n
Spree::Core::Engine.load_seed if defined?(Spree::Core)
Spree::Auth::Engine.load_seed if defined?(Spree::Auth)
      SEEDS
    end

    def install_migrations
      silence_warnings { run 'bundle exec rake railties:install:migrations' }
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
      unless options[:skip_install_data]
        puts "************************************************************************************************************"
        puts "Be sure to add the following three lines to your application's config/routes.rb file to finish setting up spree"
        puts "mount Spree::Promo::Engine, :at => '/'"
        puts "mount Spree::Auth::Engine, :at => '/'"
        puts "mount Spree::Core::Engine, :at => '/'"
      end
    end
  end
end
