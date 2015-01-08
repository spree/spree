module Spree
  module Stock
    class Estimator
      attr_reader :order, :currency

      def initialize(order)
        @order = order
        @currency = order.currency
      end

      def shipping_rates(package, shipping_method_filter = ShippingMethod::DISPLAY_ON_FRONT_END)
        rates = calculate_shipping_rates(package, shipping_method_filter)
        choose_default_shipping_rate(rates)
        sort_shipping_rates(rates)
      end

      private
      def choose_default_shipping_rate(shipping_rates)
        unless shipping_rates.empty?
          shipping_rates.min_by(&:cost).selected = true
        end
      end

      def sort_shipping_rates(shipping_rates)
        shipping_rates.sort_by!(&:cost)
      end

      def calculate_shipping_rates(package, ui_filter)
        shipping_methods(package, ui_filter).map do |shipping_method|
          cost = shipping_method.calculator.compute(package)
          tax_category = shipping_method.tax_category
          if tax_category
            tax_rate = tax_category.tax_rates.detect do |rate|
              # If the rate's zone matches the order's zone, a positive adjustment will be applied.
              # If the rate is from the default tax zone, then a negative adjustment will be applied.
              # See the tests in shipping_rate_spec.rb for an example of this.d
              rate.zone == order.tax_zone || rate.zone.default_tax?
            end
          end

          if cost
            rate = shipping_method.shipping_rates.new(cost: cost)
            rate.tax_rate = tax_rate if tax_rate
          end

          rate
        end.compact
      end

      def shipping_methods(package, display_filter)
        package.shipping_methods.select do |ship_method|
          calculator = ship_method.calculator
          begin
            ship_method.available_to_display(display_filter) &&
            ship_method.include?(order.ship_address) &&
            calculator.available?(package) &&
            (calculator.preferences[:currency].blank? ||
             calculator.preferences[:currency] == currency)
          rescue Exception => exception
            log_calculator_exception(ship_method, exception)
          end
        end
      end

      def log_calculator_exception(ship_method, exception)
        Rails.logger.info("Something went wrong calculating rates with the #{ship_method.name} (ID=#{ship_method.id}) shipping method.")
        Rails.logger.info("*" * 50)
        Rails.logger.info(exception.backtrace.join("\n"))
      end
    end
  end
end
