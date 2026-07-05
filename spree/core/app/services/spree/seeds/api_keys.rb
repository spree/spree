module Spree
  module Seeds
    class ApiKeys
      prepend Spree::ServiceModule::Base

      def call
        store = Spree::Store.default
        return unless store&.persisted?

        unless store.api_keys.active.publishable.exists?
          store.api_keys.create!(name: 'Default', key_type: 'publishable')
        end
      end
    end
  end
end
