module Spree
  module Seeds
    # The Wholesale group is the B2B approval primitive until 6.1 Company
    # accounts land: membership marks an approved wholesale buyer and is what
    # wholesale price lists key off.
    class CustomerGroups
      prepend Spree::ServiceModule::Base
      include StoreScoped

      WHOLESALE_NAME = 'Wholesale'.freeze

      private

      def seed(store)
        store.customer_groups.find_or_create_by!(name: WHOLESALE_NAME)
      end
    end
  end
end
