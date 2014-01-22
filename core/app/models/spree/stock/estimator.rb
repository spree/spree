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
          rate = shipping_method.shipping_rates.new(:cost => cost) unless cost.nil?
          shipping_rates << rate unless rate.nil?
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
        
        notify_no_eligible_methods if shipping_rates.select(&:selected?).none?

        shipping_rates
      end

      private
      # If all calculators claim to be unavailable, pass an error upstream
      def notify_no_eligible_methods
        order.errors.add(:base, Spree.t(:no_eligible_shipping_methods_found))
      end

      def shipping_methods(package)
        package.shipping_methods.select do |ship_method|
          calculator = ship_method.calculator
          begin
            calculator.available?(package) &&
            ship_method.include?(order.ship_address) &&
            (calculator.preferences[:currency].nil? ||
             calculator.preferences[:currency] == currency)
          rescue Exception => exception
            log_calculator_exception(ship_method, exception)
          end
        end
      end

      def calculate_cost(shipping_method, package)
        shipping_method.calculator.compute(package)
      end

      def log_calculator_exception(ship_method, exception)
        Rails.logger.error("Something went wrong calculating rates with the #{ship_method.name} (ID=#{ship_method.id}) shipping method.")
        Rails.logger.error("*" * 50)
        Rails.logger.error(exception.backtrace.join("\n"))
      end
    end
  end
end
