module Spree
  module Seeds
    # The store's first publishable key, so a storefront can connect before
    # anyone opens the admin. Keys bound to a channel come with the store
    # defaults, alongside the channel itself.
    class ApiKeys
      prepend Spree::ServiceModule::Base
      include StoreScoped

      private

      def seed(store)
        return if store.api_keys.active.publishable.where(channel_id: nil).exists?

        store.api_keys.create!(name: 'Default', key_type: 'publishable')
      end
    end
  end
end
