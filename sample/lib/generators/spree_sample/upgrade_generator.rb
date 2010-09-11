module SpreeSample
  module Generators
    class UpgradeGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Upgrade an existing Rails application to use with a new version of Spree."

      def copy_stuff
        directory 'db'
      end

    end
  end
end