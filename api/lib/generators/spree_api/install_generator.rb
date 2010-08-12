module SpreeApi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Configures an existing Rails application to use spree_api"

      def copy_migrations
        directory "db"
      end

    end
  end
end