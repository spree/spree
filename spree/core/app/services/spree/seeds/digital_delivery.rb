module Spree
  module Seeds
    class DigitalDelivery
      prepend Spree::ServiceModule::Base
      include StoreScoped

      private

      def seed(store)
        # Digital goods are a distinct product set, so they get their own
        # profile; assigning a product to it is what makes it digital.
        profile = Spree::DeliveryProfiles::Digital.find_by(store: store) ||
                  Spree::DeliveryProfiles::Digital.create!(store: store, name: I18n.t('spree.seed.delivery_profiles.digital'))

        digital_delivery_method = Spree::DeliveryMethod.find_or_initialize_by(name: Spree.t('digital.digital_delivery'), store: store)

        digital_delivery_method.delivery_profile = profile
        digital_delivery_method.storefront_visible = true
        digital_delivery_method.fulfillment_provider = 'Spree::FulfillmentProvider::Digital'
        # Explicit, because the calculator's own default is the default
        # store's currency rather than this store's.
        digital_delivery_method.calculator ||= Spree::Calculator::Shipping::DigitalDelivery.create!(
          preferred_currency: store.default_currency
        )
        digital_delivery_method.save!
      end
    end
  end
end
