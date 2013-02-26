module Spree
  module Stock
    class Estimator
      attr_reader :order, :currency

      def initialize(order)
        @order = order
        @currency = order.currency
      end

      def shipping_rates(package)
        shipping_rates = Array.new
        shipping_methods = shipping_methods(package)
        return [] unless shipping_methods
        shipping_methods.each do |shipping_method|
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
        shipping_methods.delete_if { |ship_method| !ship_method.calculator.available?(package.contents) }
        shipping_methods.delete_if { |ship_method| !ship_method.zone.include?(order.ship_address) }
        shipping_methods.delete_if { |ship_method| !(ship_method.calculator.preferences[:currency].nil? || ship_method.calculator.preferences[:currency] == currency) }
        shipping_methods
      end

      def calculate_cost(shipping_method, package)
        shipping_method.calculator.compute(self)
      end
    end
  end
end
