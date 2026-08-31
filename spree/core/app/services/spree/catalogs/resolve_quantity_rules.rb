module Spree
  module Catalogs
    # Answers "how may this buyer order this variant" by walking their
    # catalogs nearest-agreement-first.
    #
    # Resolution is **per field**, not all-or-nothing: the first catalog that
    # states a minimum wins the minimum, the first that states a multiple wins
    # the multiple, and an agreement silent on a field passes it through to
    # the next one rather than waiving it — a distributor catalog with no
    # stated minimum must not silently drop the channel default's. Within one
    # catalog the variant override row beats the catalog's own default
    # columns. Nothing anywhere leaves the variant's own base rules.
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
      alias for_variant call

      # The order minimum in effect for a currency: the first catalog with a
      # row for it. Catalogs saying nothing about this currency pass through,
      # so a distributor agreement priced only in EUR does not waive the
      # channel default's USD threshold.
      #
      # @param currency [String]
      # @return [Spree::CatalogOrderMinimum, nil]
      def order_minimum(currency)
        return nil if currency.blank?

        code = currency.to_s.upcase
        catalogs.each do |catalog|
          row = minimums_for(catalog)[code]
          return row if row
        end
        nil
      end

      # True when no catalog states any quantity term, so every variant
      # resolves to its own base rules. Lets callers skip the walk entirely.
      # @return [Boolean]
      def blank?
        catalogs.none? { |catalog| catalog.commercial_terms? }
      end

      def self.catalogs_for(purchase)
        store = purchase.store
        return [] if store.nil?

        company = purchase.try(:resolved_company)
        user = purchase.try(:user)
        channel = purchase.try(:channel)

        if store == Spree::Current.store
          Spree::Current.catalogs_for(company: company, user: user, channel: channel)
        else
          Spree::Catalog.for_context(store: store, company: company, user: user, channel: channel)
        end
      end
      private_class_method :catalogs_for

      private

      attr_reader :catalogs

      # Loaded per catalog on first touch and kept: a cart asks about many
      # variants against the same few catalogs, and one query each beats one
      # query per line.
      def override_for(catalog, variant)
        @overrides ||= {}
        @overrides[catalog.id] ||= catalog.quantity_rules.index_by(&:variant_id)
        @overrides[catalog.id][variant.id]
      end

      def minimums_for(catalog)
        @minimums ||= {}
        @minimums[catalog.id] ||= catalog.order_minimums.index_by { |row| row.currency.to_s.upcase }
      end
    end
  end
end
