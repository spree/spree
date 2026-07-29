module Spree
  module Seeds
    class DigitalDelivery
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.all.find_each do |store|
          create_for(store)
        end
      end

      private

      def create_for(store)
        digital_delivery_method = Spree::DeliveryMethod.find_or_initialize_by(name: Spree.t('digital.digital_delivery'), store: store)

        digital_delivery_method.display_on = 'both'
        digital_delivery_method.fulfillment_type = 'digital'
        digital_delivery_method.fulfillment_provider = 'Spree::FulfillmentProvider::Digital'
        digital_delivery_method.calculator ||= Spree::Calculator::Shipping::DigitalDelivery.create!
        digital_delivery_method.save!
      end
    end
  end
end
