# https://github.com/spree/spree/issues/1439
require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class DigitalDelivery < ShippingCalculator
      preference :amount, :decimal, default: 0
      preference :currency, :string, default: -> { Spree::Config[:currency] }

      def self.description
        Spree.t(:digital_delivery, scope: 'digital')
      end

      def compute_package(_package = nil)
        preferred_amount
      end

      def available?(package)
        package.contents.all? { |content| content.variant.digital? }
      end
    end
  end
end
