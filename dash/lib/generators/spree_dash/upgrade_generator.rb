module SpreeDash
  module Generators
    class UpgradeGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Upgrade an existing Rails application to use with a new version of Spree."

      def copy_public
        directory "public"
      end

    end
  end
end