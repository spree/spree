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

      # Order matters: API keys bind to the wholesale channel that Channels
      # creates. Seeds::All runs the same list across every store.
      SEEDS = [
        TaxCategories,
        Channels,
        Roles,
        DigitalDelivery,
        PaymentMethods,
        ProductTypes,
        CustomerGroups,
        ReturnsEnvironment,
        CommissionRates,
        SellerRequirements,
        ApiKeys,
        SavedReports,
        AllowedOrigins
      ].freeze

      # @param store [Spree::Store] the store to seed, already persisted
      # @return [Spree::ServiceModule::Result]
      def call(store:)
        # A nil store would fall through to every seed's all-stores mode.
        raise ArgumentError, 'store is required' if store.nil?

        Spree::Events.disable do
          ActiveRecord::Base.no_touching do
            SEEDS.each { |seed| seed.call(store: store) }
          end
        end
      end
    end
  end
end
