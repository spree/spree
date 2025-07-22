module Spree
  module Seeds
    class DigitalDelivery
      prepend Spree::ServiceModule::Base

      def call
        digital_shipping_category = Spree::ShippingCategory.find_or_create_by!(name: 'Digital')
        zones = Spree::Zone.all

        digital_shipping_method = Spree::ShippingMethod.find_or_initialize_by(name: Spree.t('digital.digital_delivery'))

        digital_shipping_method.display_on = 'both'
        digital_shipping_method.shipping_categories = [digital_shipping_category]
        digital_shipping_method.calculator ||= Spree::Calculator::Shipping::DigitalDelivery.create!
        digital_shipping_method.zones = zones
        digital_shipping_method.save!
      end
    end
  end
end
