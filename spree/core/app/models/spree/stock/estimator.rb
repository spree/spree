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

      # Whether any delivery method is eligible to carry this package — the
      # same eligibility a rate refresh applies, stopping short of asking any
      # rate provider for a price. Allocation reads it to prefer an origin
      # whose methods can actually reach the destination, so it must never
      # cost a carrier API call.
      #
      # @param package [Spree::Stock::Package]
      # @param audience [Symbol] {Spree::DeliveryMethod::STOREFRONT} (default)
      #   or {Spree::DeliveryMethod::BACKOFFICE}
      # @return [Boolean]
      def deliverable?(package, audience = DeliveryMethod::STOREFRONT)
        delivery_methods(package, audience).any?
      end

      # @deprecated Use {#delivery_rates}; removed in 6.1.
      def shipping_rates(package, audience = DeliveryMethod::STOREFRONT)
        Spree::Deprecation.warn('Spree::Stock::Estimator#shipping_rates is deprecated and will be removed in Spree 6.1. Use #delivery_rates instead.')
        delivery_rates(package, audience)
      end

      private

      # Shipping is what "delivery" means unless someone chooses otherwise, so
      # the cheapest *shipped* rate wins by default. Picking the cheapest of
      # all rates handed every order to free store pickup the moment a pickup
      # method existed. Profiles offering nothing shipped (pickup-only,
      # digital) still get their cheapest rate.
      def choose_default_delivery_rate(delivery_rates)
        return if delivery_rates.empty?

        shipped = delivery_rates.select { |rate| rate.delivery_method&.requires_address? }
        candidates = shipped.presence || delivery_rates
        # An unpriced rate costs zero, so preselecting on price alone would
        # hand every mixed offering to freight. Prefer something actually
        # priced; fall back to freight when that is all there is.
        priced = candidates.reject(&:unpriced?)
        (priced.presence || candidates).min_by(&:cost).selected = true
      end

      # Cheapest first, with unpriced rates after the priced ones — their zero
      # cost is an absence of information, not a bargain.
      def sort_delivery_rates(delivery_rates)
        delivery_rates.sort_by! { |rate| [rate.unpriced? ? 1 : 0, rate.cost] }
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

            delivery_method.delivery_rates.new(
              cost: rate_cost(estimate, delivery_method, service_row, provider),
              tax_rate: (first_tax_rate_for(delivery_method.tax_category) unless estimate.unpriced),
              unpriced: estimate.unpriced,
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

      # An unpriced quote has no amount to mark up or tax — a percentage of an
      # unknown price is still unknown, and rounding zero through the VAT
      # gross-up would only invent a number. Its cost stays zero and every
      # display surface reads +unpriced+ instead.
      def rate_cost(estimate, delivery_method, service_row, provider)
        return 0 if estimate.unpriced

        cost = apply_markup(estimate.cost, delivery_method, service_row, provider)
        gross_amount(cost, taxation_options_for(delivery_method))
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
          address: @order.tax_address,
          country: @order.tax_country,
          market: @order.market
        }
      end

      def first_tax_rate_for(tax_category)
        return unless @order.tax_address && tax_category

        scope = Spree::TaxRate.for_tax_category(tax_category).for_address(@order.tax_address)
        scope = scope.for_store(@order.store) if @order.store
        scope.first
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

        # On a marketplace, a package's seller is its stock location's, and it
        # is quoted by that seller's own methods plus whatever the operator
        # shares. This is the one place that decision is made
        # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
        package_seller_id = package.stock_location&.seller_id

        methods.select do |delivery_method|
          calculator = delivery_method.calculator

          offered_to_seller?(delivery_method, package_seller_id) &&
            delivery_method.available_to?(audience) &&
            delivery_method.include?(order.ship_address) &&
            delivery_method.serves_location?(package.stock_location) &&
            delivery_method.eligible_for_package?(package) &&
            calculator.available?(package) &&
            calculator.supports_currency?(currency)
        end
      end

      # A seller's package is quoted by that seller's own methods plus the
      # marketplace ones the operator shares; a first-party package sees the
      # marketplace's methods only.
      def offered_to_seller?(delivery_method, package_seller_id)
        return delivery_method.seller_id.nil? if package_seller_id.nil?
        return true if delivery_method.seller_id == package_seller_id

        delivery_method.seller_id.nil? && delivery_method.available_to_sellers?
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
