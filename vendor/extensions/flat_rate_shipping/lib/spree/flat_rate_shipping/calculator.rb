module Spree
  module FlatRateShipping
    class Calculator
      def self.calculate_shipping(order)
        return Spree::FlatRateShipping::Config[:flat_rate_amount]
      end
    end
  end
end