module SpreeBootstrapFrontend
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../templates", __FILE__)

      def copy_stylesheets
        copy_file 'stylesheets/spree_bootstrap_frontend.css.scss',
                  'app/assets/stylesheets/spree/frontend/spree_bootstrap_frontend.css.scss'
      end
    end
  end
end
