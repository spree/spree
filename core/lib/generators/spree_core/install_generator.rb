module SpreeCore
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Configures an existing Rails application to use Spree."

      def create_lib_files
        template 'spree_site.rb', "lib/spree_site.rb"
      end

      def configure_application_controller
        template 'application_controller.rb', 'app/controllers/application_controller.rb'
        remove_file 'app/views/layouts/application.html.erb'
      end

      def additional_tweaks
        remove_file "public/index.html"

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

        append_file "db/seeds.rb", <<-SEEDS
        \n
        Rake::Task["db:load_dir"].invoke( "default" )
        puts "Default data has been loaded"
        SEEDS
      end

      def copy_migrations
        directory "db"
        create_file ".rspec", "--colour"
      end

      def copy_public
        directory "public"
      end

      def config_middleware
        application 'config.middleware.use "SeoAssist"'
        application 'config.middleware.use "RedirectLegacyProductUrl"'
        application 'config.middleware.use "CreateAdminUser"'
      end

      def require_site
        application "require 'spree_site'"
      end

    end
  end
end
