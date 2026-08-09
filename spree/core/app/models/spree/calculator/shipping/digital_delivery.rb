require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class DigitalDelivery < ShippingCalculator
      include Spree::Calculator::CurrencyAmounts

      preference :amount, :decimal, default: 0
      preference :currency, :string, default: -> { Spree::Store.default.default_currency }

      def self.description
        Spree.t('digital.digital_delivery')
      end

      def compute_package(package = nil)
        currency = package.respond_to?(:currency) ? package.currency : nil
        currency ? amount_for(currency) : preferred_amount
      end

      def available?(package)
        package.contents.all? { |content| content.variant.digital? }
      end
    end
  end
end
