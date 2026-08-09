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

      # Quoting runs through the method's rate provider — Internal prices
      # through the calculator, carrier providers call their API and may
      # return several estimates (one per carrier service). An empty result
      # suppresses the method, matching the calculator contract. Service
      # filtering, markup, naming, VAT gross-up, tax resolution and sorting
      # stay here so every provider gets them identically.
      def calculate_delivery_rates(package, audience)
        delivery_methods(package, audience).flat_map do |delivery_method|
          provider = delivery_method.rate_provider_instance

          provider.estimates(package).filter_map do |estimate|
            next unless delivery_method.offers_service?(estimate)
            # A quote in another currency (a USD carrier account under a EUR
            # cart) is unusable — mislabeling it would misprice checkout.
            if estimate.currency.present? && estimate.currency.casecmp(currency) != 0
              Rails.logger.debug { "Spree::Stock::Estimator: dropping #{delivery_method.name} estimate quoted in #{estimate.currency} for a #{currency} order" }
              next
            end

            service_row = delivery_method.service_for(estimate)
            cost = apply_markup(estimate.cost, delivery_method, service_row, provider)

            delivery_method.delivery_rates.new(
              cost: gross_amount(cost, taxation_options_for(delivery_method)),
              tax_rate: first_tax_rate_for(delivery_method.tax_category),
              name: rate_name(estimate, service_row),
              carrier: estimate.carrier,
              service_level: estimate.service_level,
              estimated_delivery_date: estimate.estimated_delivery_date,
              # presence: rates are rewritten on every refresh, so calculator-
              # priced methods store NULL rather than an empty hash each time.
              metadata: estimate.metadata.presence
            )
          end
        end
      end

      # Handling fee on top of provider quotes: the service row's values when
      # set, else the method-level defaults. Calculator-priced methods are
      # exempt — their calculator IS the price.
      def apply_markup(cost, delivery_method, service_row, provider)
        return cost if provider.class.uses_calculator?

        percent = service_row&.markup_percent || delivery_method.markup_percent || 0
        flat = service_row&.markup_flat || delivery_method.markup_flat || 0
        (cost * (1 + (percent / 100)) + flat).round(2)
      end

      # Display name for provider-priced rates: the merchant's label override,
      # else carrier + service from the quote. Nil for calculator rates —
      # DeliveryRate#name falls back to the method name.
      def rate_name(estimate, service_row)
        service_row&.label.presence || estimate.name.presence ||
          [estimate.carrier, estimate.service_level].compact.join(' ').presence
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
      # estimates) filters through here, and host apps override it to add
      # their own rules.
      #
      # Dispatches through the legacy +shipping_methods+ name so overrides
      # written against it keep running until 6.1 — without this, a host
      # override would be silently skipped and checkout could quote rates
      # the host meant to filter out.
      def delivery_methods(package, audience)
        return shipping_methods(package, audience) if overrides_legacy_seam?

        filter_delivery_methods(package, audience)
      end

      # @deprecated Call or override {#delivery_methods}; removed in 6.1.
      # Only reached when a caller uses the old name directly — the override
      # dispatch above goes straight to the override's own definition.
      def shipping_methods(package, audience)
        Spree::Deprecation.warn('Spree::Stock::Estimator#shipping_methods is deprecated and will be removed in Spree 6.1. Use #delivery_methods instead.')
        filter_delivery_methods(package, audience)
      end

      def filter_delivery_methods(package, audience)
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
            calculator.supports_currency?(currency)
        end
      end

      # True when a subclass or decorator redefined the legacy seam, so its
      # filtering still applies.
      def overrides_legacy_seam?
        return @overrides_legacy_seam if defined?(@overrides_legacy_seam)

        @overrides_legacy_seam =
          method(:shipping_methods).owner != Spree::Stock::Estimator
      end
    end
  end
end
