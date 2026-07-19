module Spree
  module Seeds
    class ApiKeys
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.find_each do |store|
          unless store.api_keys.active.publishable.where(channel_id: nil).exists?
            store.api_keys.create!(name: 'Default', key_type: 'publishable')
          end

          wholesale = store.channels.find_by(code: Channels::WHOLESALE_CODE)
          if wholesale && !store.api_keys.active.publishable.where(channel: wholesale).exists?
            store.api_keys.create!(name: 'Storefront (Wholesale)', key_type: 'publishable', channel: wholesale)
          end
        end
      end
    end
  end
end
