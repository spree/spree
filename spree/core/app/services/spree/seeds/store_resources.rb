module Spree
  module Seeds
    # Seeds what a single store needs to trade, without touching any other
    # store — for platforms that create stores continuously, where seeding a
    # new store must not cost a pass over every existing one.
    #
    # Country-shaped defaults (market, warehouse, delivery zones, pickup) are
    # not part of it: the caller runs Spree::Stores::ProvisionDefaults
    # afterwards with the merchant's answers.
    class StoreResources
      prepend Spree::ServiceModule::Base

      # @param store [Spree::Store] the store to seed, already persisted
      # @return [Spree::ServiceModule::Result]
      def call(store:)
        # A nil store would fall through to every seed's all-stores mode.
        raise ArgumentError, 'store is required' if store.nil?

        Spree::Events.disable do
          ActiveRecord::Base.no_touching do
            TaxCategories.call(store: store)
            Channels.call(store: store)
            Roles.call(store: store)
            DigitalDelivery.call(store: store)
            PaymentMethods.call(store: store)
            ProductTypes.call(store: store)
            CustomerGroups.call(store: store)
            ReturnsEnvironment.call(store: store)
            CommissionRates.call(store: store)
            SellerRequirements.call(store: store)
            # Binds to the wholesale channel that Channels creates above.
            ApiKeys.call(store: store)
            SavedReports.call(store: store)
            AllowedOrigins.call(store: store)
          end
        end
      end
    end
  end
end
