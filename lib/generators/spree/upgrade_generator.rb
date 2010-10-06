module Spree
  module Generators
    class UpgradeGenerator < Rails::Generators::Base
      desc "Upgrade an existing Rails application to use with a new version of Spree."

      def run_generators
        generate 'spree_core:update', '-f'
        generate 'spree_api:update', '-f'
        generate 'spree_auth:update', '-f'
        generate 'spree_dash:update', '-f'
        generate 'spree_promo:update', '-f'
        generate 'spree_sample:update', '-f'
      end

    end
  end
end