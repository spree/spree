module Spree
  module Stock
    class Estimator
      include VatPriceCalculation

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

          next unless cost
          shipping_method.shipping_rates.new(
            cost: gross_amount(cost, taxation_options_for(shipping_method)),
            tax_rate: first_tax_rate_for(shipping_method.tax_category)
          )
        end.compact
      end

      # Override this if you need the prices for shipping methods to be handled just like the
      # prices for products in terms of included tax manipulation.
      #
      def taxation_options_for(shipping_method)
        {
          tax_category: shipping_method.tax_category,
          tax_zone: @order.tax_zone
        }
      end

      def first_tax_rate_for(tax_category)
        return unless @order.tax_zone && tax_category
        Spree::TaxRate.for_tax_category(tax_category).
          potential_rates_for_zone(@order.tax_zone).first
      end

      def shipping_methods(package, display_filter)
        package.shipping_methods.select do |ship_method|
          calculator = ship_method.calculator

          ship_method.available_to_display?(display_filter) &&
            ship_method.include?(order.ship_address) &&
            calculator.available?(package) &&
            (calculator.preferences[:currency].blank? ||
             calculator.preferences[:currency] == currency)
        end
      end
    end
  end
end
