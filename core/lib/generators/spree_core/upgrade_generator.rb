module SpreeCore
  module Generators
    class UpgradeGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Upgrade an existing Rails application to use with a new version of Spree."

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
      end
    end
  end
end
