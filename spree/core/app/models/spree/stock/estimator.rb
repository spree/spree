module Spree
  module Stock
    class Estimator
      include Spree::VatPriceCalculation

      attr_reader :order, :currency

      def initialize(order)
        @order = order
        @currency = order.currency
      end

      # @param package [Spree::Stock::Package]
      # @param audience [Symbol] {Spree::DeliveryMethod::STOREFRONT} (default)
      #   or {Spree::DeliveryMethod::BACKOFFICE}
      # @return [Array<Spree::DeliveryRate>]
      def delivery_rates(package, audience = DeliveryMethod::STOREFRONT)
        rates = calculate_delivery_rates(package, audience)
        choose_default_delivery_rate(rates)
        sort_delivery_rates(rates)
      end

      # @deprecated Use {#delivery_rates}; removed in 6.1.
      def shipping_rates(package, audience = DeliveryMethod::STOREFRONT)
        Spree::Deprecation.warn('Spree::Stock::Estimator#shipping_rates is deprecated and will be removed in Spree 6.1. Use #delivery_rates instead.')
        delivery_rates(package, audience)
      end

      private

      def choose_default_delivery_rate(delivery_rates)
        unless delivery_rates.empty?
          delivery_rates.min_by(&:cost).selected = true
        end
      end

      def sort_delivery_rates(delivery_rates)
        delivery_rates.sort_by!(&:cost)
      end

      def calculate_delivery_rates(package, audience)
        delivery_methods(package, audience).map do |delivery_method|
          cost = delivery_method.calculator.compute(package)

          next unless cost

          delivery_method.delivery_rates.new(
            cost: gross_amount(cost, taxation_options_for(delivery_method)),
            tax_rate: first_tax_rate_for(delivery_method.tax_category)
          )
        end.compact
      end

      # Override this if you need the prices for delivery methods to be handled just like the
      # prices for products in terms of included tax manipulation.
      #
      def taxation_options_for(delivery_method)
        {
          tax_category: delivery_method.tax_category,
          tax_zone: @order.tax_zone
        }
      end

      def first_tax_rate_for(tax_category)
        return unless @order.tax_zone && tax_category

        Spree::TaxRate.for_tax_category(tax_category).
          potential_rates_for_zone(@order.tax_zone).first
      end

      # The eligibility seam: every rate consumer (checkout, routing, cart
      # estimates) filters through here.
      def delivery_methods(package, audience)
        methods = package.eligible_delivery_methods
        # Storeless orders exist only in specs; real orders always carry one.
        methods = methods.merge(order.store.delivery_methods) if order.store

        methods.select do |delivery_method|
          calculator = delivery_method.calculator

          delivery_method.available_to?(audience) &&
            delivery_method.include?(order.ship_address) &&
            delivery_method.serves_location?(package.stock_location) &&
            delivery_method.eligible_for_package?(package) &&
            calculator.available?(package) &&
            (calculator.preferences[:currency].blank? ||
             calculator.preferences[:currency] == currency)
        end
      end

      # @deprecated Use {#delivery_methods}; removed in 6.1.
      def shipping_methods(package, audience)
        Spree::Deprecation.warn('Spree::Stock::Estimator#shipping_methods is deprecated and will be removed in Spree 6.1. Use #delivery_methods instead.')
        delivery_methods(package, audience)
      end
    end
  end
end
