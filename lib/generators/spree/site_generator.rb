module Spree
  module Generators
    class SiteGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Configures an existing Rails application to use Spree."

      def create_lib_files
        template 'spree_site.rb', "lib/spree_site.rb"
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

      def config_middleware
        application 'config.middleware.use "SeoAssist"'
        application 'config.middleware.use "RedirectLegacyProductUrl"'
      end

      def require_site
        application "require 'spree_site'"
      end

    end
  end
end
