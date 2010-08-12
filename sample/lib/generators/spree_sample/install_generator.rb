module SpreeSample
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Copies sample fixtures and images into your Spree application."

      def copy_stuff
        directory 'db'
      end

    end
  end
end