module SpreeAuth
  module Generators
    class UpgradeGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Configures your Rails application for use with spree_auth."

      def copy_migrations
        directory "db"
      end
    end
  end
end
