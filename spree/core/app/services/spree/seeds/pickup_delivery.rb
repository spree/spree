module Spree
  module Seeds
    # Collection at a merchant counter. Rides the store's default profile
    # (the same physical goods ship or get collected) with no zone — pickup
    # has no destination, only an origin, and the Pickup provider decides
    # which locations can hand goods over.
    class PickupDelivery
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.all.find_each do |store|
          create_for(store)
        end
      end

      private

      def create_for(store)
        profile = store.default_delivery_profile
        return if profile.nil?

        # A counter to collect from is what makes pickup real, so the store's
        # default location opens for collection unless one already has.
        if store.stock_locations.where(pickup_enabled: true).none?
          store.stock_locations.find_by(default: true)&.update!(pickup_enabled: true)
        end
        return if store.stock_locations.where(pickup_enabled: true).none?

        delivery_method = Spree::DeliveryMethod.find_or_initialize_by(
          name: Spree.t('pickup.store_pickup'), store: store
        )

        delivery_method.delivery_profile = profile
        delivery_method.storefront_visible = true
        delivery_method.fulfillment_provider = 'Spree::FulfillmentProvider::Pickup'
        delivery_method.calculator ||= Spree::Calculator::Shipping::FlatRate.new(
          preferences: { amount: 0, currency: store.default_currency }
        )
        delivery_method.save!

        # No configured counters means every pickup-enabled location, which
        # is what a fresh store wants; seeding the links would freeze the set.
      end
    end
  end
end
