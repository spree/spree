module Spree
  module Seeds
    class DigitalDelivery
      prepend Spree::ServiceModule::Base

      def call
        digital_delivery_method = Spree::DeliveryMethod.find_or_initialize_by(name: Spree.t('digital.digital_delivery'))

        digital_delivery_method.display_on = 'both'
        digital_delivery_method.fulfillment_type = 'digital'
        digital_delivery_method.calculator ||= Spree::Calculator::Shipping::DigitalDelivery.create!
        digital_delivery_method.save!
      end
    end
  end
end
