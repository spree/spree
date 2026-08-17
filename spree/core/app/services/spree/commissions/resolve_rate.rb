# frozen_string_literal: true

module Spree
  module Commissions
    # Picks the commission rate that governs one line item.
    #
    # Walks the store's enabled rates in list order and takes the first whose
    # targeting admits the sale. Precedence is therefore the order an operator
    # sees in the table, not a hardcoded product-beats-category-beats-seller
    # ladder: seeded rates arrive in the conventional order, so a marketplace
    # that never touches it still gets the expected answer, and one that wants
    # a different answer drags a row.
    #
    # Returns nil when nothing matches, which is a real answer — a marketplace
    # with no rate for a sale charges no commission, rather than falling back
    # to some default the operator never configured.
    #
    # Swap through +Spree.commissions_resolve_rate_service+.
    class ResolveRate
      prepend Spree::ServiceModule::Base

      # @param line_item [Spree::LineItem] the sale being commissioned
      # @param vendor [Spree::Vendor] its seller
      # @param store [Spree::Store]
      # @param currency [String] the order's currency
      # @param rates [Array<Spree::CommissionRate>, nil] pre-loaded candidates,
      #   so commissioning a whole order reads the table once instead of once
      #   per line
      # @param categories [Hash{Integer=>Array<Spree::Category>}, nil] each
      #   product's categories with their ancestors, resolved once for the
      #   order — see .categories_for
      # @return [Spree::CommissionRate, nil]
      def call(line_item:, vendor:, store:, currency: nil, rates: nil, categories: nil)
        currency ||= line_item.currency
        candidates = rates || self.class.candidates_for(store)
        subjects = subjects_for(line_item, vendor, categories)

        success(
          candidates.find do |rate|
            rate.applies_to_currency?(currency) && rate.matches_subjects?(subjects)
          end
        )
      end

      # The store's rates in resolution order, with rules preloaded — matching
      # reads every rule of every candidate, so without this each rate costs a
      # query per line item.
      #
      # @param store [Spree::Store]
      # @return [Array<Spree::CommissionRate>]
      def self.candidates_for(store)
        store.commission_rates.enabled.ordered.includes(:commission_rules).to_a
      end

      # Each product's categories together with their ancestors, keyed by
      # product id.
      #
      # Resolved for a whole set of products at once because walking a nested
      # set is a query per category, and this runs inside checkout: asking per
      # line item would cost a query for every category of every item in the
      # basket, most of them the same ones over and over.
      #
      # @param products [Array<Spree::Product>]
      # @return [Hash{Integer=>Array<Spree::Category>}]
      def self.categories_for(products)
        products = products.compact.uniq
        return {} if products.empty?

        by_product = products.to_h { |product| [product.id, product.categories.to_a] }
        ancestors = ancestors_of(by_product.values.flatten.uniq)

        by_product.transform_values do |categories|
          categories.flat_map { |category| ancestors.fetch(category.id, [category]) }.uniq
        end
      end

      # Every category above each of the given ones, in one query per store
      # rather than one per category. Nested sets make an ancestor a plain
      # range comparison, so the whole set can be asked for at once.
      #
      # @param categories [Array<Spree::Category>]
      # @return [Hash{Integer=>Array<Spree::Category>}]
      def self.ancestors_of(categories)
        return {} if categories.empty?

        table = Spree::Category.arel_table
        # Kept per store rather than flattened into one pool: bounds are only
        # meaningful within the tree that assigned them, so a category from
        # another store can enclose these ones by coincidence — and a rate
        # targeting it would then match a sale it has nothing to do with.
        pool_by_store = categories.group_by(&:store_id).transform_values do |group|
          reaching = group.map { |c| table[:lft].lteq(c.lft).and(table[:rgt].gteq(c.rgt)) }.reduce(:or)
          Spree::Category.where(store_id: group.first.store_id).where(reaching).to_a
        end

        categories.to_h do |category|
          ancestors = pool_by_store.fetch(category.store_id, []).select do |node|
            node.lft <= category.lft && node.rgt >= category.rgt
          end

          [category.id, ancestors]
        end
      end

      private

      # What this sale offers a rule to match on. Categories include ancestors,
      # so a rate targeting "Electronics" also governs a camera filed under
      # "Electronics → Cameras" — the alternative would make a merchant restate
      # every leaf whenever they add one.
      def subjects_for(line_item, vendor, categories)
        product = line_item.variant&.product

        {
          'Spree::Vendor' => [vendor],
          'Spree::Product' => [product].compact,
          'Spree::Category' => product_categories(product, categories)
        }
      end

      def product_categories(product, categories)
        return [] if product.nil?
        return categories.fetch(product.id, []) if categories

        self.class.categories_for([product]).fetch(product.id, [])
      end
    end
  end
end
