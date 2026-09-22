module Spree
  module Seeds
    # The marketplace's starting checklist for new sellers.
    #
    # Only the requirements core can answer on its own — accept the terms,
    # fill in a profile, give both addresses, list something. What a
    # particular marketplace additionally asks for (a business registration,
    # a licence) is theirs to add, and there is no sensible default for it.
    class SellerRequirements
      prepend Spree::ServiceModule::Base
      include StoreScoped

      private

      def seed(store)
        Spree::SellerRequirement.provision_defaults(store)
      end
    end
  end
end
