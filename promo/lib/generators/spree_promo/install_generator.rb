module SpreePromo
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Configures an existing Rails application to use spree_promotions"

      def copy_migrations
        directory "db"
      end

      def copy_public
        directory "public"
      end

    end
  end
end