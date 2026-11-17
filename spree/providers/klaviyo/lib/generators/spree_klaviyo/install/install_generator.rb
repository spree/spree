require 'rails/generators'
require 'spree/core'

module SpreeKlaviyo
  module Generators
    # Kept as a no-op so `rake test_app` and any existing
    # `rails g spree_klaviyo:install` invocations keep working. The integration
    # registers itself from the engine and stores its configuration in
    # integration preferences, so it owns no tables and has nothing to copy
    # into the host app.
    class InstallGenerator < Rails::Generators::Base
      desc 'No-op. spree_klaviyo registers its integration automatically and ships no migrations.'

      def notify_nothing_to_install
        say 'spree_klaviyo registers its integration automatically — nothing to install. ' \
            'Add Klaviyo under Settings → Integrations in the admin to enter your private API key and list id.'
      end
    end
  end
end
