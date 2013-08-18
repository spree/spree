module Spree
  module Stock
    class Estimator
      attr_reader :order, :currency

      def initialize(order)
        @order = order
        @currency = order.currency
      end

      def shipping_rates(package, frontend_only = true)
        shipping_rates = Array.new
        shipping_methods = shipping_methods(package)
        return [] unless shipping_methods

        shipping_methods.each do |shipping_method|
          cost = calculate_cost(shipping_method, package)
          shipping_rates << shipping_method.shipping_rates.new(:cost => cost) unless cost.nil?
        end

        shipping_rates.sort_by! { |r| r.cost || 0 }

        unless shipping_rates.empty?
          if frontend_only
            shipping_rates.each do |rate|
              rate.selected = true and break if rate.shipping_method.frontend?
            end
          else
            shipping_rates.first.selected = true
          end
        end

        shipping_rates
      end

      private
      def shipping_methods(package)
        shipping_methods = package.shipping_methods
        shipping_methods.delete_if { |ship_method| !ship_method.calculator.available?(package) }
        shipping_methods.delete_if { |ship_method| !ship_method.include?(order.ship_address) }
        shipping_methods.delete_if { |ship_method| !(ship_method.calculator.preferences[:currency].nil? || ship_method.calculator.preferences[:currency] == currency) }
        shipping_methods
      end

      def calculate_cost(shipping_method, package)
        shipping_method.calculator.compute(package)
      end
    end
  end
end
