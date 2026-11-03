module Spree
  class Product
    # Which markets may see and buy a product. Channel publications answer
    # which surfaces show it; this answers which territories, and a buyer sees
    # the product only where both agree. Nothing is derived or stored about
    # the combination — both are evaluated per request
    # (docs/plans/6.1-product-market-availability.md).
    #
    # A NULL mode means every market, so only restricted products carry rows,
    # and a market added later is excluded by +only+ and included by
    # +all_except+ without anything being written.
    module MarketAvailability
      extend ActiveSupport::Concern

      MARKET_AVAILABILITY_MODES = %w[all all_except only].freeze

      included do
        # No +dependent:+, like publications: destroy soft-deletes the product,
        # and a restored product must come back with its restrictions rather
        # than visible in the markets it was kept out of.
        has_many :market_availability_entries, class_name: 'Spree::ProductMarketAvailability', inverse_of: :product
        has_many :markets, through: :market_availability_entries, class_name: 'Spree::Market'

        validates :market_availability, inclusion: { in: MARKET_AVAILABILITY_MODES - ['all'] }, allow_nil: true
        validate :restricted_market_availability_names_a_market
        after_save :forget_market_availability_markets, if: -> { market_availability.nil? && saved_change_to_market_availability? }
      end

      class_methods do
        # Products a buyer in the market may see. No market — a store that has
        # none — restricts nothing.
        #
        # @param market [Spree::Market, nil]
        # @return [ActiveRecord::Relation<Spree::Product>]
        def available_in_market(market)
          return all unless market

          where(
            "#{quoted_table_name}.market_availability IS NULL OR " \
            "(#{quoted_table_name}.market_availability = 'all_except' AND NOT #{market_listed_sql}) OR " \
            "(#{quoted_table_name}.market_availability = 'only' AND #{market_listed_sql})",
            market_id: market.id
          )
        end

        # The inverse of {.available_in_market}, reading only restricted products.
        #
        # @param market [Spree::Market, nil]
        # @return [ActiveRecord::Relation<Spree::Product>]
        def excluded_from_market(market)
          return none unless market

          where(
            "(#{quoted_table_name}.market_availability = 'all_except' AND #{market_listed_sql}) OR " \
            "(#{quoted_table_name}.market_availability = 'only' AND NOT #{market_listed_sql})",
            market_id: market.id
          )
        end

        private

        def market_listed_sql
          entries = Spree::ProductMarketAvailability.quoted_table_name
          "EXISTS (SELECT 1 FROM #{entries} WHERE #{entries}.product_id = #{quoted_table_name}.id " \
            "AND #{entries}.market_id = :market_id)"
        end
      end

      # @param value [String, nil] +all+, +all_except+ or +only+; +all+ is stored as NULL
      def market_availability=(value)
        super(value.to_s == 'all' ? nil : value.presence)
      end

      # Accepts prefixed or raw ids; markets of another store are dropped.
      def market_ids=(ids)
        decoded_ids = Array(ids).filter_map do |id|
          id.to_s.include?('_') ? Spree::Market.decode_prefixed_id(id) : id
        end
        super(Spree::Market.for_store(assignable_store).where(id: decoded_ids).ids)
      end

      # @param market [Spree::Market, nil]
      # @return [Boolean]
      def available_in_market?(market)
        return true if market_availability.nil? || market.nil?

        listed = market_availability_market_ids.include?(market.id)
        market_availability == 'only' ? listed : !listed
      end

      # Read through the association so a listing preloads it once for every row.
      #
      # @return [Array<Integer>] the named markets' ids
      def market_availability_market_ids
        market_availability_entries.map(&:market_id)
      end

      private

      def restricted_market_availability_names_a_market
        return if market_availability.nil? || market_ids.any?

        errors.add(:market_ids, :market_required)
      end

      def forget_market_availability_markets
        market_availability_entries.delete_all(:delete_all)
      end
    end
  end
end
