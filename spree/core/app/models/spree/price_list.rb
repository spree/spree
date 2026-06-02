module Spree
  class PriceList < Spree.base_class
    has_prefix_id :pl

    acts_as_paranoid
    acts_as_list scope: :store_id

    include Spree::SingleStoreResource

    MATCH_POLICIES = %w[all any].freeze

    belongs_to :store, class_name: 'Spree::Store'

    has_many :price_rules, class_name: 'Spree::PriceRule', autosave: true, dependent: :destroy
    alias rules price_rules
    has_many :prices, class_name: 'Spree::Price', dependent: :destroy_async
    has_many :variants, -> { distinct }, through: :prices, source: :variant
    has_many :products, -> { distinct }, through: :variants, source: :product
    alias price_list_products products

    # Override default nested attributes to use bulk_update_prices for performance
    attr_reader :prices_attributes

    # Sets the prices attributes for bulk update
    # @param attributes [Array<Hash>] array of price attributes with :id, :amount, :compare_at_amount
    # @return [Array<Hash>] array of price attributes with :id, :amount, :compare_at_amount
    def prices_attributes=(attributes)
      @prices_attributes = attributes.values
    end

    after_update :process_bulk_prices_update
    after_save :apply_pending_rules
    after_save :apply_pending_product_ids
    after_save :apply_pending_prices

    # @return [Array<String>] prefixed product ids in this list,
    #   encoded inline to avoid hydrating N Product records.
    def product_prefixed_ids
      prefix = Spree::Product._prefix_id_prefix
      product_ids.sort.map { |pk| "#{prefix}_#{Spree::PrefixedId::SQIDS.encode([pk])}" }
    end

    # Reconciles list membership. Removes prices for products no longer
    # in `ids` and adds placeholder prices for the new ones.
    #
    # @param ids [Array<String>] raw product PKs (prefixed strings are
    #   resolved upstream by `Spree::Base#assign_attributes`).
    # @return [void]
    def product_ids=(ids)
      @pending_product_ids = Array(ids).compact.uniq
    end

    # Flat-payload writer for `prices`. Bulk-upserts the listed rows in
    # `after_save` so newly-added products have their placeholder rows
    # materialized first. Nullability contract:
    #   - `nil` → no-op
    #   - `[]`  → clear every override on this list
    #   - `[…]` → upsert listed rows, leave the rest alone
    #
    # @param rows [Array<Hash>, Array<Spree::Price>, nil]
    # @return [void]
    def prices=(rows)
      first = Array(rows).first
      return super(rows) if first.is_a?(Spree::Price)
      return if rows.nil?

      @pending_prices = Array(rows).map do |row|
        row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h.with_indifferent_access : row.with_indifferent_access
      end
      @pending_prices_clear = rows.empty?
    end

    # Flat-payload writer for `rules`. See
    # {Spree::TypedAssociations#assign_typed_association}.
    def rules=(rows)
      assign_typed_association(:price_rules, rows)
    end

    validates :name, :store, presence: true
    validates :match_policy, presence: true, inclusion: { in: MATCH_POLICIES }
    validate :starts_at_before_ends_at

    self.whitelisted_ransackable_attributes = %w[status match_policy starts_at ends_at]

    scope :by_position, -> { order(position: :asc) }
    scope :for_store, ->(store) { where(store: store) }
    scope :current, lambda { |timezone = nil|
      timezone ||= Rails.application.config.time_zone
      # Round to beginning of minute to enable Rails query caching
      current_time = Time.current.in_time_zone(timezone).beginning_of_minute
      where('starts_at IS NULL OR starts_at <= ?', current_time)
        .where('ends_at IS NULL OR ends_at >= ?', current_time)
    }

    state_machine :status, initial: :draft do
      event :activate do
        transition to: :active
      end

      event :deactivate do
        transition to: :inactive
      end

      event :schedule do
        transition to: :scheduled
      end
    end

    # Returns price lists applicable for a given pricing context
    # - active: always applies (within date range)
    # - scheduled: applies only within starts_at/ends_at date range
    def self.for_context(context)
      timezone = context.store&.preferred_timezone || 'UTC'
      for_store(context.store)
        .with_status(:active, :scheduled)
        .current(timezone)
        .by_position
    end

    def self.match_policies
      MATCH_POLICIES.map { |key| [Spree.t(key), key] }
    end

    # Returns true if the price list is applicable to the context
    # @param context [Spree::Pricing::Context]
    # @return [Boolean]
    def applicable?(context)
      return false unless active_or_scheduled?
      return false unless within_date_range?(context.date || Time.current)

      rules_applicable?(context)
    end

    # Returns true if the price list rules are applicable to the context
    # @param context [Spree::Pricing::Context]
    # @return [Boolean]
    def rules_applicable?(context)
      return true if price_rules.none?

      case match_policy
      when 'all'
        price_rules.all? { |rule| rule.applicable?(context) }
      when 'any'
        price_rules.any? { |rule| rule.applicable?(context) }
      else
        false
      end
    end

    # Returns true if the price list is active or scheduled
    # @return [Boolean]
    def active_or_scheduled?
      active? || scheduled?
    end

    # Returns true if the price list is currently in effect
    # (active, or scheduled and within date range)
    def currently_active?
      active_or_scheduled? && within_date_range?(Time.current)
    end

    # Adds products to the list, materializing a placeholder price
    # (amount nil) for every variant × store currency.
    #
    # @param product_ids [Array<String>] raw product PKs
    # @return [void]
    def add_products(product_ids)
      return if product_ids.blank?

      currencies = store.supported_currencies_list.map(&:iso_code)
      variant_ids = Spree::Variant.eligible.where(product_id: product_ids).distinct.pluck(:id)
      return if variant_ids.empty?

      existing = prices.where(variant_id: variant_ids)
                       .pluck(:variant_id, :currency)
                       .to_set

      now = Time.current

      prices_to_insert = variant_ids.flat_map do |variant_id|
        currencies.filter_map do |currency|
          next if existing.include?([variant_id, currency])

          {
            variant_id: variant_id,
            currency: currency,
            amount: nil,
            price_list_id: id,
            created_at: now,
            updated_at: now
          }
        end
      end

      return if prices_to_insert.empty?

      # Use upsert_all with on_duplicate: :skip to handle race conditions
      Spree::Price.upsert_all(prices_to_insert, on_duplicate: :skip)
      touch_variants(variant_ids)
      touch
    end

    # Removes products from the list. Hard-deletes their prices so the
    # unique index doesn't block re-adding the same products later
    # (acts_as_paranoid would leave soft-deleted rows blocking the
    # `(variant_id, currency, price_list_id)` slot).
    #
    # @param product_ids [Array<String>] raw product PKs
    # @return [void]
    def remove_products(product_ids)
      return if product_ids.blank?

      variant_ids = Spree::Variant.where(product_id: product_ids).distinct.pluck(:id)
      return if variant_ids.empty?

      # Use delete_all for hard delete - this bypasses acts_as_paranoid
      # which is required for the unique index to work when re-adding products
      prices.where(variant_id: variant_ids).delete_all
      touch_variants(variant_ids)
      touch
    end

    # Bulk update prices using upsert_all for performance
    # @param prices_attributes [Array<Hash>] array of price attributes with :id, :amount, :compare_at_amount
    # @return [Boolean] true if successful
    def bulk_update_prices(prices_attributes)
      return true if prices_attributes.blank?

      records_to_upsert = []
      variant_ids = Set.new

      # Get current values for comparison
      price_ids = prices_attributes.map { |a| a[:id] || a['id'] }.compact.map(&:to_i)
      current_values = prices.where(id: price_ids).pluck(:id, :amount, :compare_at_amount).to_h { |id, amount, compare_at| [id, { amount: amount, compare_at_amount: compare_at }] }

      prices_attributes.each do |attrs|
        attrs = (attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h : attrs.to_h).with_indifferent_access
        next if attrs[:id].blank?

        price_id = attrs[:id].to_i
        # Reject rows that aren't in *this* list's prices — `upsert_all`
        # otherwise keys solely by primary id and would silently cross
        # list boundaries.
        next unless current_values.key?(price_id)

        current = current_values[price_id]

        # Parse amounts using LocalizedNumber for proper decimal handling
        amount = attrs[:amount].present? ? Spree::LocalizedNumber.parse(attrs[:amount]) : nil
        compare_at_amount = attrs[:compare_at_amount].present? ? Spree::LocalizedNumber.parse(attrs[:compare_at_amount]) : nil

        # Clear compare_at_amount if it equals amount
        compare_at_amount = nil if compare_at_amount == amount

        # Skip if nothing changed
        next if amount == current[:amount] && compare_at_amount == current[:compare_at_amount]

        records_to_upsert << {
          id: price_id,
          variant_id: attrs[:variant_id].to_i,
          currency: attrs[:currency],
          amount: amount,
          compare_at_amount: compare_at_amount,
          price_list_id: id
        }

        variant_ids << attrs[:variant_id].to_i
      end

      return true if records_to_upsert.empty?

      opts = { update_only: [:amount, :compare_at_amount], on_duplicate: :update }
      opts[:unique_by] = :id unless mysql_adapter?

      Spree::Price.upsert_all(records_to_upsert, **opts)

      touch_variants(variant_ids.to_a)
      true
    end

    private

    # Processes the bulk prices update
    # @return [void]
    def process_bulk_prices_update
      return if @prices_attributes.blank?

      bulk_update_prices(@prices_attributes)
      @prices_attributes = nil
    end

    def apply_pending_rules
      flush_pending_typed_association(:price_rules)
    end

    def apply_pending_product_ids
      return unless @pending_product_ids

      desired = @pending_product_ids
      @pending_product_ids = nil

      current = product_ids
      to_remove = current - desired
      to_add = desired - current

      remove_products(to_remove) if to_remove.any?
      add_products(to_add) if to_add.any?
    end

    def apply_pending_prices
      pending = @pending_prices
      cleared = @pending_prices_clear
      return if pending.nil?

      @pending_prices = nil
      @pending_prices_clear = nil

      if cleared
        variant_ids = prices.distinct.pluck(:variant_id)
        prices.update_all(amount: nil, compare_at_amount: nil, updated_at: Time.current)
        touch_variants(variant_ids)
        return
      end

      rows = pending.filter_map do |row|
        # `variant_id` may arrive as a prefixed string (legacy callers,
        # console) or already decoded (the controller's `permitted_params`
        # runs through `normalize_params`). Handle both.
        raw = row[:variant_id]
        variant_id = Spree::PrefixedId.prefixed_id?(raw) ? Spree::PrefixedId.decode_prefixed_id(raw) : raw
        next if variant_id.blank? || row[:currency].blank?

        {
          variant_id: variant_id,
          currency: row[:currency],
          price_list_id: id,
          amount: row[:amount],
          compare_at_amount: row[:compare_at_amount]
        }
      end
      return if rows.empty?

      Spree::Prices::BulkUpsert.call(rows: rows)
      touch_variants(rows.map { |r| r[:variant_id] }.uniq)
    end

    # Touches the variants in a background job
    # @param variant_ids [Array<String>] array of variant ids
    # @return [void]
    def touch_variants(variant_ids)
      return if variant_ids.blank?

      Spree::Variants::TouchJob.perform_later(variant_ids)
    end

    def starts_at_before_ends_at
      return if starts_at.blank? || ends_at.blank?

      if starts_at >= ends_at
        errors.add(:ends_at, :must_be_after_starts_at)
      end
    end

    # Returns true if the date is within the price list date range
    # @param date [Time] the date to check
    # @return [Boolean]
    def within_date_range?(date)
      timezone = store&.preferred_timezone || Rails.application.config.time_zone
      date_in_tz = date.in_time_zone(timezone)

      return false if starts_at.present? && date_in_tz < starts_at
      return false if ends_at.present? && date_in_tz > ends_at

      true
    end
  end
end
