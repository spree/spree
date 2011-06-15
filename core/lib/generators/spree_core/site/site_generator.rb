module SpreeCore
  module Generators
    class SiteGenerator < Rails::Generators::Base
      def self.source_paths
        [File.expand_path('../templates', __FILE__)]
      end

      def generate_app
        #used in sandbox_generator
      end

      def set_destination
        # self.destination_root = File.expand_path("sandbox", destination_root)
      end

      def remove_unneeded_files
        remove_file "public/index.html"
      end

      def replace_gemfile

      end

      def setup_environments
         #used in test_app_generator
      end

      def tweak_gemfile

      end

      def append_db_adapter_gem

      end

      def bundle_install
        inside application_path do
          run 'bundle install'
        end
      end

      def additional_tweaks
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

      def include_seed_data
        append_file "db/seeds.rb", <<-SEEDS
        \n
        SpreeCore::Engine.load_seed if defined?(SpreeCore)
        SpreeAuth::Engine.load_seed if defined?(SpreeAuth)
        SEEDS
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

      def config_middleware
        application 'config.middleware.use "SeoAssist"'
        application 'config.middleware.use "RedirectLegacyProductUrl"'
      end

      def create_databases_yml
        #used in sandbox_generator
      end

      def copy_migrations
        inside application_path do
          run 'rake railties:install:migrations'
        end
      end

      def run_migrations
        #used in sandbox_generator
      end

      private
      def application_path
        Dir.pwd
      end

      def remove_directory_if_exists(path)
        run "rm -r #{path}" if File.directory?(path)
      end

      def additions_for_gemfile
        #used in sandbox_generator
        #should be a hash of { :gem_name => "/full/path/to/gem" }
        { :spree => nil }
      end


    end
  end
end
