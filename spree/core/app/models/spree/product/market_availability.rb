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

        validates :market_availability, inclusion: { in: MARKET_AVAILABILITY_MODES - ['all'] }, allow_nil: true
        validate :restricted_market_availability_names_a_market
        after_save :save_market_availability_markets
      end

      class_methods do
        # Products a buyer in the market may see. No market — a store that has
        # none — restricts nothing.
        #
        # @param market [Spree::Market, nil]
        # @return [ActiveRecord::Relation<Spree::Product>]
        def available_in_market(market)
          return all unless market

          entries = Spree::ProductMarketAvailability.quoted_table_name
          listed = "EXISTS (SELECT 1 FROM #{entries} WHERE #{entries}.product_id = #{quoted_table_name}.id " \
                   "AND #{entries}.market_id = :market_id)"

          where(
            "#{quoted_table_name}.market_availability IS NULL OR " \
            "(#{quoted_table_name}.market_availability = 'all_except' AND NOT #{listed}) OR " \
            "(#{quoted_table_name}.market_availability = 'only' AND #{listed})",
            market_id: market.id
          )
        end
      end

      # @param value [String, nil] +all+, +all_except+ or +only+; +all+ is stored as NULL
      def market_availability=(value)
        super(value.to_s == 'all' ? nil : value.presence)
      end

      # @return [String] the mode as the API names it, +all+ for no restriction
      def market_availability_mode
        market_availability || 'all'
      end

      # Staged until the product saves, like channel publications, so a write
      # the save refuses changes no markets. Markets of another store are
      # dropped; a soft-deleted one the product already names is kept, so
      # saving the form it was read into does not lose the restriction.
      def market_ids=(ids)
        already_named = assignable_ids(Spree::Market.with_deleted, ids) & market_availability_entries.map(&:market_id)
        @pending_market_ids = assignable_ids(Spree::Market, ids) | already_named
      end

      def market_ids
        @pending_market_ids || market_availability_market_ids
      end

      def reload(*)
        @pending_market_ids = nil
        super
      end

      # @param market [Spree::Market, nil]
      # @return [Boolean]
      def available_in_market?(market)
        return true if market_availability.nil? || market.nil?

        listed = market_availability_market_ids.include?(market.id)
        market_availability == 'only' ? listed : !listed
      end

      # Read through the association so a listing preloads it once for every
      # row. Rows naming a market since deleted stay, so restoring the market
      # restores the restriction.
      #
      # @return [Array<Integer>] the named markets' ids
      def market_availability_market_ids
        return [] if market_availability.nil?

        market_availability_entries.map(&:market_id)
      end

      # @return [Array<String>] the named markets' prefixed ids
      def market_availability_prefixed_market_ids
        market_availability_market_ids.map { |id| Spree::Market.prefixed_id_for(id) }
      end

      private

      # Switching between the two restricted modes flips what the markets
      # mean, so the switch has to name them again.
      def restricted_market_availability_names_a_market
        return if market_availability.nil?
        return if market_ids.any? && (@pending_market_ids || market_availability_was.nil? || !market_availability_changed?)

        errors.add(:market_ids, :market_required)
      end

      # Unrestricted products keep no rows, whatever ids came with the write.
      def save_market_availability_markets
        return unless @pending_market_ids || saved_change_to_market_availability?

        target_ids = market_availability.nil? ? [] : @pending_market_ids
        @pending_market_ids = nil
        return if target_ids.nil?

        current_ids = market_availability_entries.map(&:market_id)
        removed_ids = current_ids - target_ids
        added_ids = target_ids - current_ids
        return if removed_ids.empty? && added_ids.empty?

        market_availability_entries.where(market_id: removed_ids).delete_all
        if added_ids.any?
          now = Time.current
          Spree::ProductMarketAvailability.insert_all(
            added_ids.map { |market_id| { product_id: id, market_id: market_id, created_at: now, updated_at: now } }
          )
        end
        market_availability_entries.reset
        touch unless saved_changes?
      end
    end
  end
end
