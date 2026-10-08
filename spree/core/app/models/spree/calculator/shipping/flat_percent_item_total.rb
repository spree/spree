module Spree
  module Calculator::Shipping
    class FlatPercentItemTotal < ShippingCalculator
      preference :flat_percent, :decimal, default: 0

      def self.description
        I18n.t('spree.flat_percent')
      end

      def compute_package(package)
        compute_from_price(total(package.contents), package.owner&.currency)
      end

      # @param price [BigDecimal]
      # @param currency [String, nil] the amount is rounded to its minor unit
      # @return [BigDecimal]
      def compute_from_price(price, currency = nil)
        Spree::Money::Rounding.to_currency(price * BigDecimal(preferred_flat_percent.to_s) / 100, currency)
      end
    end
  end
end
