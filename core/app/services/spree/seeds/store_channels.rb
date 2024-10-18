module Spree
  module Seeds
    class StoreChannels
      prepend Spree::ServiceModule::Base

      def call(store)
        Spree::StoreChannel.find_or_create_by!(name: 'Online store', store: store)
        Spree::StoreChannel.find_or_create_by!(name: 'Back-office', store: store)
        Spree::StoreChannel.find_or_create_by!(name: 'Retail', store: store)
      end
    end
  end
end
