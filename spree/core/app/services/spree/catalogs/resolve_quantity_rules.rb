module Spree
  module Catalogs
    # Answers "how may this buyer order this variant" by walking their
    # catalogs nearest-agreement-first.
    #
    # Resolution is **per field**, not all-or-nothing: the first catalog that
    # states a minimum wins the minimum, the first that states a multiple wins
    # the multiple, and an agreement silent on a field passes it through to
    # the next rather than waiving it — a nearer catalog with no stated
    # minimum must not silently drop the one behind it. Within a single
    # catalog the variant override row beats that catalog's own default
    # columns. Nothing anywhere leaves the variant's own base rules.
    #
    # The catalogs walked are whatever {Spree::Catalog.for_buyer} resolved,
    # and that chain is exclusive by tier: a buyer with company catalogs never
    # also carries their customer group's or the channel's default. So a
    # channel-wide term is the floor for buyers who resolve NO company or
    # group catalog, not a fallback beneath one — a company agreement that
    # states nothing about a field lands on the variant's base rule, not on
    # the channel default.
    #
    # Built once per cart or request and reused: resolving a fifty-line cart
    # must not be fifty passes over the same catalogs.
    class ResolveQuantityRules
      # @param catalogs [Array<Spree::Catalog>] nearest agreement first
      def initialize(catalogs)
        @catalogs = Array(catalogs)
      end

      # Builds a resolver for a purchase's buyer, reusing the request's
      # already-resolved catalog set where the purchase belongs to the store
      # being served.
      #
      # @param purchase [Spree::Cart, Spree::Order]
      # @return [Spree::Catalogs::ResolveQuantityRules]
      def self.for_purchase(purchase)
        new(catalogs_for(purchase))
      end

      # @param variant [Spree::Variant]
      # @return [Spree::QuantityRule] the buyer's effective rules
      def call(variant)
        return variant.quantity_rule if catalogs.empty?

        minimum = nil
        multiple = nil

        catalogs.each do |catalog|
          override = override_for(catalog, variant)

          minimum ||= override&.minimum_order_quantity || catalog.minimum_order_quantity
          multiple ||= override&.order_multiple || catalog.order_multiple

          break if minimum && multiple
        end

        Spree::QuantityRule.new(
          minimum_order_quantity: minimum || variant.minimum_order_quantity,
          order_multiple: multiple || variant.order_multiple
        )
      end

      # The order minimum in effect for a currency: the first catalog with a
      # row for it. Catalogs saying nothing about this currency pass through,
      # so an agreement priced only in EUR does not waive a USD threshold set
      # by another catalog in the same tier.
      #
      # @param currency [String]
      # @return [Spree::CatalogOrderMinimum, nil]
      def order_minimum(currency)
        return nil if currency.blank? || catalogs.empty?

        code = currency.to_s.upcase
        catalogs.each do |catalog|
          row = minimums_for(catalog)[code]
          return row if row
        end
        nil
      end

      # Through the one entry point every catalog-reading surface uses, so a
      # cart's terms come from the same agreement its prices did.
      def self.catalogs_for(purchase)
        Spree::Catalog.for_buyer(
          store: purchase.store,
          customer: purchase.try(:customer),
          company: purchase.try(:resolved_company),
          channel: purchase.try(:channel)
        )
      end
      private_class_method :catalogs_for

      private

      attr_reader :catalogs

      # One indexed row read per (catalog, variant), memoized: an agreement
      # may state terms for thousands of SKUs, so loading the whole table to
      # answer about one variant would put that on the add-to-cart path. The
      # composite unique index makes the keyed read cheap.
      def override_for(catalog, variant)
        @overrides ||= {}
        key = [catalog.id, variant.id]
        return @overrides[key] if @overrides.key?(key)

        @overrides[key] = catalog.quantity_rules.find_by(variant_id: variant.id)
      end

      def minimums_for(catalog)
        @minimums ||= {}
        @minimums[catalog.id] ||= catalog.order_minimums.index_by { |row| row.currency.to_s.upcase }
      end
    end
  end
end
