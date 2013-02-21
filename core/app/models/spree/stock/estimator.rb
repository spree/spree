module Spree
  module Stock
    class Estimator
      attr_reader :order

      def initialize(order)
        @order = order
      end

      def shipping_rates(package)
        shipping_rates = Array.new
        shipping_methods(package).each do |shipping_method|
          cost = calculate_cost(shipping_method, package)

          shipping_rates << ShippingRate.new(
                                      :id => shipping_method.id,
                                      :shipping_method => shipping_method,
                                      :name => shipping_method.name,
                                      :cost => cost,
                                      :currency => package.currency)
        end
        shipping_rates
      end

      private
      def shipping_methods(package)
        shipping_methods = package.shipping_category.shipping_methods
        # TODO filter methods by zone or from location
        shipping_methods
      end

      def calculate_cost(shipping_method, package)
        shipping_method.calculator.compute(self)
      end
    end
  end
end
