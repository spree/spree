module SpreeFrontend
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../templates", __FILE__)

      def copy_stylesheets
        copy_file 'stylesheets/bootstrap_frontend.css.scss',
                  'app/assets/stylesheets/spree/frontend/bootstrap_frontend.css.scss'
        copy_file 'stylesheets/all.css',
                  'vendor/assets/stylesheets/spree/frontend/all.css'
      end
    end
  end
end
