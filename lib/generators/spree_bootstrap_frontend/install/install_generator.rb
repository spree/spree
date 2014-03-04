module SpreeBootstrapFrontend
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../templates", __FILE__)

      def add_javascripts
        # append_file 'app/assets/javascripts/store/all.js', "//= require store/spree_bootstrap_frontend\n"
        # append_file 'app/assets/javascripts/admin/all.js', "//= require admin/spree_bootstrap_frontend\n"
      end

      def add_stylesheets
        copy_file 'stylesheets/spree_bootstrap_frontend.css.scss',
                  'app/assets/stylesheets/spree/frontend/spree_bootstrap_frontend.css.scss'
        copy_file 'stylesheets/all.css',
                  'app/assets/stylesheets/spree/frontend/all.css'
        # inject_into_file 'app/assets/stylesheets/store/all.css', " *= require store/spree_bootstrap_frontend\n", :before => /\*\//, :verbose => true
        # inject_into_file 'app/assets/stylesheets/admin/all.css', " *= require admin/spree_bootstrap_frontend\n", :before => /\*\//, :verbose => true
      end
    end
  end
end
