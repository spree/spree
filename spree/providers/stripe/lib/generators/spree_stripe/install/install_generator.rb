require 'rails/generators'
require 'spree/core'

module SpreeStripe
  module Generators
    # Kept as a no-op so `rake test_app` and any existing
    # `rails g spree_stripe:install` invocations keep working. The gateway
    # registers itself from the engine and stores its configuration in payment
    # method preferences, so it owns no tables and has nothing to copy into the
    # host app.
    class InstallGenerator < Rails::Generators::Base
      desc 'No-op. spree_stripe registers its gateway automatically and ships no migrations.'

      def notify_nothing_to_install
        say 'spree_stripe registers its gateway automatically — nothing to install. ' \
            'Add a Stripe payment method in the admin to configure your API keys.'
      end
    end
  end
end
