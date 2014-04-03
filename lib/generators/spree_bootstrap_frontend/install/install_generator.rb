module SpreeBootstrapFrontend
  module Generators
    class InstallGenerator < Rails::Generators::Base

      source_root File.expand_path("../templates", __FILE__)

      def add_javascripts
      end

      def add_stylesheets
        copy_file 'stylesheets/spree_bootstrap_frontend.css.scss',
                  'vendor/assets/stylesheets/spree/frontend/spree_bootstrap_frontend.css.scss'
        copy_file 'stylesheets/all.css',
                  'vendor/assets/stylesheets/spree/frontend/all.css'
      end

    end
  end
end
