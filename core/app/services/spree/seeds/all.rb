module Spree
  module Seeds
    class All
      prepend Spree::ServiceModule::Base

      def call
        Countries.call
        DefaultReimbursementType.call
        Roles.call
        States.call
        StoreCreditCategories.call
        Stores.call
        Zones.call
      end
    end
  end
end
