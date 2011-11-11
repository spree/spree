require 'rails/generators'

module Spree
  class SiteGenerator < Rails::Generators::Base
    argument :after_bundle_only, :type => :string, :default => "false"

    class_option :lib_name, :default => 'spree'
    attr :lib_name

    def self.source_paths
      [File.expand_path('../templates', __FILE__)]
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

  end
end
