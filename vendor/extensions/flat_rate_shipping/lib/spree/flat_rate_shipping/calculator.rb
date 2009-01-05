module Spree
  module FlatRateShipping
    class Calculator
      def calculate_shipping(shipment)
        return Spree::FlatRateShipping::Config[:flat_rate_amount]
      end
    end
  end
end