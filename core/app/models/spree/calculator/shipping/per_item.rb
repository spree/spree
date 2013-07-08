require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class PerItem < ShippingCalculator
      preference :amount, :decimal, :default => 0
      preference :currency, :string, :default => Spree::Config[:currency]
      attr_accessible :preferred_amount, :preferred_currency

      def self.description
        Spree.t(:shipping_flat_rate_per_item)
      end
      
      def compute_package(object)
        return 0 if object.nil?
        if object.is_a?(Spree::Order)
          self.preferred_amount * object.line_items.map(&:quantity).sum
        else
          content_items = object.contents
          self.preferred_amount * content_items.sum { |item| item.quantity }
        end
      end
      
    end
  end
end
