require 'generators/spree_core'
require 'rails/generators/named_base'

module Spree
  module Generators
    class SiteGenerator < Rails::Generators::Base
      extend Spree::Generators::TemplatePath

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
        Rake::Task["db:load_dir"].invoke( "default" )
        puts "Default data has been loaded"
        SEEDS
      end

      def require_site
        application "require 'spree_site'"
      end

      def install_spree_auth
        generate 'spree_auth:install'
      end

      def sync_spree_files
        rake 'spree:sync'
      end
    end
  end
end