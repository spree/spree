require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class HandlingChargeOnVariant < ShippingCalculator
      preference :currency, :string, default: ->{ Spree::Config[:currency] }

      def self.description
        Spree.t(:shipping_handling_charge_on_variant)
      end

      def compute_shipment(shipment)
        compute_quantity(shipment.manifest.sum{|item| item.quantity * item.variant.handling_charge})
      end
      
    end
  end
end
