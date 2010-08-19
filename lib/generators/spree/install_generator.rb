module Spree
  module Generators
    class InstallGenerator < Rails::Generators::Base
      #source_root File.expand_path("../../templates", __FILE__)

      desc "Configures an existing Rails application to use Spree."

      def run_generators
        generate 'spree_core:install', '-f'
        generate 'spree_api:install', '-f'
        generate 'spree_auth:install', '-f'
        generate 'spree_dashboard:install', '-f'
        generate 'spree_promotions:install', '-f'
        generate 'spree_sample:install', '-f'
      end

    end
  end
end
