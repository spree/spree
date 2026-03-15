module Spree
  module Seeds
    class AllowedOrigins
      prepend Spree::ServiceModule::Base

      def call
        store = Spree::Store.default
        return unless store&.persisted?

        store.allowed_origins.find_or_create_by!(origin: 'http://localhost')
      end
    end
  end
end
