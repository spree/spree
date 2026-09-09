module Spree
  class PriceList < Spree.base_class
    has_prefix_id :pl

    acts_as_paranoid
    acts_as_list scope: :store_id

    include Spree::SingleStoreResource
    include Spree::HasListPosition

    MATCH_POLICIES = %w[all any].freeze

    belongs_to :store, class_name: 'Spree::Store'
    # The owning agreement, or nil for a standalone list. An owned list is
    # reached only through its catalog — generic rule matching skips it in
    # SQL (see .for_context) — so a deactivated catalog's list goes dormant
    # instead of leaking back into store-wide matching. `touch` keeps the
    # catalog's cache key honest when its pricing changes.
    belongs_to :catalog, class_name: 'Spree::Catalog', optional: true, inverse_of: :price_list, touch: true

    has_many :price_rules, class_name: 'Spree::PriceRule', autosave: true, dependent: :destroy
    alias rules price_rules
    has_many :prices, class_name: 'Spree::Price', dependent: :destroy_async
    # The higher bands of this list's percentage adjustment; the column is its
    # quantity-1 value (docs/plans/6.0-volume-pricing.md).
    has_many :price_adjustment_tiers, -> { by_quantity }, class_name: 'Spree::PriceAdjustmentTier',
             inverse_of: :price_list, autosave: true, dependent: :destroy
    has_many :variants, -> { distinct }, through: :prices, source: :variant
    has_many :products, -> { distinct }, through: :variants, source: :product
    alias price_list_products products

    after_save :apply_pending_rules

    # Request-scoped memoization of the generic matching set must not keep a
    # set that a write in the same request has already superseded — a status
    # flip or a catalog attach/detach changes which lists match generically.
    after_commit -> { Spree::Current.price_lists = nil }

    # Flat-payload writer for `rules`. See
    # {Spree::TypedAssociations#assign_typed_association}.
    def rules=(rows)
      assign_typed_association(:price_rules, rows)
    end

    # Flat-payload writer for the percentage's quantity bands: the payload is
    # the whole ladder, so a band the caller left out is one they removed.
    # A merchant editing a ladder is editing one thing, and sending three
    # rows to mean "these three, and only these" is how the editor reads.
    #
    # @param rows [Array<Hash>] `[{ min_quantity:, percentage: }, ...]`
    # @return [void]
    def price_adjustment_tiers=(rows)
      rows = Array(rows)
      # Records rather than a payload: Rails assigns those on an association
      # swap, and the ordinary setter is what it expects.
      return super if rows.first.is_a?(Spree.base_class)

      wanted = rows.map { |row| row.respond_to?(:to_h) ? row.to_h.with_indifferent_access : row }
      by_quantity = price_adjustment_tiers.index_by(&:min_quantity)

      kept = wanted.map do |row|
        # Assigned raw rather than coerced with `to_i`: a value that is not a
        # number would become 0 and read as a band to drop, so a single typo
        # would silently delete the whole ladder and report success. Left as
        # it arrived, the tier's own numericality validation refuses the save
        # and names the row (docs/plans/6.0-volume-pricing.md).
        quantity = Spree::PriceAdjustmentTier.type_for_attribute(:min_quantity).cast(row[:min_quantity])

        tier = by_quantity[quantity] || price_adjustment_tiers.build(min_quantity: row[:min_quantity])
        tier.percentage = row[:percentage]
        tier
      end

      (price_adjustment_tiers - kept).each(&:mark_for_destruction)
    end

    validates :name, presence: true
    validates :match_policy, presence: true, inclusion: { in: MATCH_POLICIES }
    # One live list per catalog; soft-deleted lists release the slot. Backed
    # by a unique index on every adapter — partial on PostgreSQL and SQLite,
    # over a stored generated column on MySQL/MariaDB.
    validates :catalog_id, uniqueness: { scope: spree_base_uniqueness_scope,
                                         conditions: -> { where(deleted_at: nil) } }, allow_nil: true
    # Greater than -100: at exactly -100 every derived price is zero, and
    # below it the arithmetic goes negative. Capped at what the
    # `decimal(6,3)` column can hold, so an accepted value cannot fail on the
    # way to the database.
    validates :price_adjustment_percentage,
              numericality: { greater_than: -100, less_than: 1000 }, allow_nil: true
    validate :starts_at_before_ends_at
    validate :catalog_in_same_store
    validate :percentage_requires_catalog

    # `catalog_id` is queryable so a picker can offer the lists that are
    # actually available — unowned, plus the one the catalog already holds.
    self.whitelisted_ransackable_attributes = %w[status match_policy starts_at ends_at catalog_id]

    scope :by_position, -> { ordered }
    scope :for_store, ->(store) { where(store: store) }
    scope :standalone, -> { where(catalog_id: nil) }
    scope :current, lambda { |timezone = nil|
      timezone ||= Rails.application.config.time_zone
      # Round to beginning of minute to enable Rails query caching
      current_time = Time.current.in_time_zone(timezone).beginning_of_minute
      where('starts_at IS NULL OR starts_at <= ?', current_time)
        .where('ends_at IS NULL OR ends_at >= ?', current_time)
    }

    # No state machine — the transitions live in the Spree::PriceLists
    # workflows (docs/plans/6.0-service-workflows.md).
    include Spree::HasStatus
    has_status :draft, :active, :inactive, :scheduled, default: :draft

    # @deprecated Call Spree.price_list_activate_workflow — removed in 6.1.
    #   Kept literal: the old event always went straight to active, and the
    #   workflow schedules a future-dated list instead. A caller relying on
    #   this shell gets what it always got.
    def activate
      Spree::Deprecation.warn('Spree::PriceList#activate is deprecated and will be removed in Spree 6.1. Call Spree.price_list_activate_workflow instead.')
      update(status: 'active')
    end

    # @deprecated Call Spree.price_list_deactivate_workflow — removed in 6.1.
    def deactivate
      Spree::Deprecation.warn('Spree::PriceList#deactivate is deprecated and will be removed in Spree 6.1. Call Spree.price_list_deactivate_workflow instead.')
      Spree.price_list_deactivate_workflow.call(price_list: self).success?
    end

    # @deprecated Call Spree.price_list_activate_workflow — removed in 6.1.
    #   It picks scheduled or active from the dates itself.
    def schedule
      Spree::Deprecation.warn('Spree::PriceList#schedule is deprecated and will be removed in Spree 6.1. Call Spree.price_list_activate_workflow instead.')
      update(status: 'scheduled')
    end

    # Returns price lists eligible for generic rule matching in a pricing
    # context:
    # - active: always applies (within date range)
    # - scheduled: applies only within starts_at/ends_at date range
    # - standalone only: a catalog-owned list is reached exclusively through
    #   its catalog, so it is excluded here in SQL — which is what keeps a
    #   deactivated catalog's (typically rule-less) list dormant instead of
    #   pricing the whole store.
    def self.for_context(context)
      timezone = context.store&.preferred_timezone || 'UTC'
      for_store(context.store)
        .standalone
        .with_status(:active, :scheduled)
        .current(timezone)
        .by_position
        # Every matched list is asked whether it prices automatically, which
        # reads its bands — without this the walk pays a query per list.
        .preload(:price_adjustment_tiers)
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
    # @param rules [Enumerable<Spree::PriceRule>] the rules to judge; the
    #   list's own by default, a subset when only some of them still have a
    #   question to answer (see #contextual_rules_applicable?)
    # @return [Boolean]
    def rules_applicable?(context, rules = price_rules)
      return true if rules.none?

      case match_policy
      when 'all' then rules.all? { |rule| rule.applicable?(context) }
      when 'any' then rules.any? { |rule| rule.applicable?(context) }
      else false
      end
    end

    # Whether an owned list still applies once its catalog has selected it.
    #
    # Only the contextual rules are asked. An owned list is reached through
    # its catalog, which already answered the audience question — re-asking a
    # customer-group or channel rule here would let a stale audience rule
    # switch off a price the agreement grants. Quantity is the case a catalog
    # cannot express, and it is what makes automatic volume pricing work
    # (docs/plans/6.0-price-list-automatic-pricing.md).
    #
    # An owned list with no contextual rules applies, which is every list
    # merchants have set up so far.
    #
    # @param context [Spree::Pricing::Context]
    # @return [Boolean]
    def contextual_rules_applicable?(context)
      rules_applicable?(context, price_rules.select(&:contextual?))
    end

    # Whether this list derives prices from base prices rather than pricing
    # only what it holds explicit rows for.
    # @return [Boolean]
    def automatic_pricing?
      # Zero is no adjustment at all: deriving base × 1.0 would stamp every
      # price with this list's id while changing nothing, and the dashboard
      # has no "0%" to show. It reads as a fixed list.
      #
      # A list whose column is blank but which carries bands still prices
      # automatically — it just prices nothing until a line reaches the first
      # band, which is the "no discount under a case" agreement.
      percentage_present?(price_adjustment_percentage) || price_adjustment_tiers.any?
    end

    # This list's percentage for a line of the given size: the deepest band it
    # reaches, or the list's own column below the first band. Quantity-1 (or
    # unknown) means the column, which is what a list carrying no bands always
    # answers (docs/plans/6.0-volume-pricing.md).
    #
    # @param quantity [Integer, nil]
    # @return [BigDecimal, nil]
    def adjustment_percentage_for(quantity = nil)
      band = band_for(quantity)
      return band.percentage if band

      price_adjustment_percentage
    end

    # What a base price is multiplied by to derive this list's price at the
    # given quantity: -15% gives 0.85, +10% gives 1.1.
    #
    # @param quantity [Integer, nil]
    # @return [BigDecimal, nil]
    def adjustment_factor(quantity = nil)
      percentage = adjustment_percentage_for(quantity)
      return if percentage.nil?

      1 + (percentage / 100)
    end

    # This list's price for a base price, derived rather than stored: the base
    # amount times the adjustment factor, rounded to the currency's own minor
    # unit. Deriving on read is what keeps an adjustment list from drifting
    # when base prices move (docs/plans/6.0-price-list-automatic-pricing.md).
    #
    # Built unsaved and never written. Lives here because how a list makes its
    # numbers is the list's own business — every caller asking "what does this
    # list charge for that base price" gets the same arithmetic, so a merchant
    # reading an agreement and a shopper being charged cannot disagree.
    #
    # @param base [Spree::Price] the variant's base price
    # @param quantity [Integer, nil] the line's size, which picks the band
    # @return [Spree::Price, nil] nil when the base carries no amount, or when
    #   no band applies at this quantity and the list has no column of its own
    def derived_price_from(base, quantity = nil)
      return if base.nil? || base.amount.nil?

      band = band_for(quantity)
      percentage = band ? band.percentage : price_adjustment_percentage
      factor = percentage && 1 + (percentage / 100)
      # A bands-only list below its first band adjusts nothing, so it prices
      # this line no more than a list holding no row for the variant does —
      # the walk moves on rather than stamping the base price with this
      # list's id.
      return if factor.nil? || factor == 1

      compare_at =
        if adjust_compare_at && base.compare_at_amount.present?
          Spree::Money::Rounding.to_currency(base.compare_at_amount * factor, base.currency)
        end

      Spree::Price.new(
        variant_id: base.variant_id,
        currency: base.currency,
        amount: Spree::Money::Rounding.to_currency(base.amount * factor, base.currency),
        compare_at_amount: compare_at,
        min_quantity: band&.min_quantity || 1,
        price_list_id: id
      )
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

      # Only the bottom rung counts as "already here": a variant priced solely
      # from a case up still needs its quantity-1 placeholder, or the editor
      # has no row to show the ladder under.
      existing = prices.where(variant_id: variant_ids, min_quantity: 1)
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
            min_quantity: 1,
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
    # `(variant_id, currency, price_list_id, min_quantity)` slot). Every rung
    # of a variant's ladder goes with it — removing a product from a list
    # removes what the list charged for it, at every quantity.
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
      current_values = prices.where(id: price_ids).pluck(:id, :amount, :compare_at_amount, :min_quantity).to_h { |id, amount, compare_at, min_quantity| [id, { amount: amount, compare_at_amount: compare_at, min_quantity: min_quantity }] }

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
          # Carried from the stored row rather than the payload: this path
          # edits amounts on rungs that already exist, and a row's quantity is
          # not something an amount edit may move.
          min_quantity: current[:min_quantity],
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

    # The deepest band this quantity reaches, or nil when it reaches none.
    # Read off the loaded association so pricing a page of variants against
    # one list does not re-query per row.
    # @param quantity [Integer, nil]
    # @return [Spree::PriceAdjustmentTier, nil]
    def band_for(quantity)
      line_quantity = quantity.to_i
      return if line_quantity < 2

      price_adjustment_tiers.select { |tier| tier.min_quantity <= line_quantity }.max_by(&:min_quantity)
    end

    # Zero is not an adjustment — see #automatic_pricing?.
    def percentage_present?(percentage)
      percentage.present? && !percentage.zero?
    end

    def apply_pending_rules
      flush_pending_typed_association(:price_rules)
    end

    # Touches the variants in a background job
    # @param variant_ids [Array<String>] array of variant ids
    # @return [void]
    def touch_variants(variant_ids)
      return if variant_ids.blank?

      Spree::Variants::TouchJob.perform_later(variant_ids)
    end

    def catalog_in_same_store
      return if catalog.nil? || store_id.nil?
      return if catalog.store_id == store_id

      errors.add(:catalog, :invalid)
    end

    # A percentage has no product scope of its own — it adjusts every variant
    # the list is asked about. Owned by a catalog, the assortment draws that
    # line; standalone, nothing does, and a rule-less list would put the
    # whole store on sale while its product list changed nothing. So the
    # feature exists only inside an agreement.
    def percentage_requires_catalog
      return if catalog_id.present?

      # Bands are the same percentage asked at a quantity, so they are refused
      # on a standalone list for the same reason the column is.
      errors.add(:price_adjustment_percentage, :requires_catalog) if price_adjustment_percentage.present?
      errors.add(:price_adjustment_tiers, :requires_catalog) if price_adjustment_tiers.any?
    end

    def starts_at_before_ends_at
      return if starts_at.blank? || ends_at.blank?

      if starts_at >= ends_at
        errors.add(:ends_at, :must_be_after_starts_at)
      end
    end

    # The store's zone, read once. `currently_active?` is asked per variant on
    # a listing, and the association behind it is a query each time
    # (docs/plans/6.0-volume-pricing.md).
    #
    # @return [String]
    def store_timezone
      return @store_timezone if defined?(@store_timezone)

      @store_timezone = store&.preferred_timezone || Rails.application.config.time_zone
    end

    # Returns true if the date is within the price list date range
    # @param date [Time] the date to check
    # @return [Boolean]
    def within_date_range?(date)
      date_in_tz = date.in_time_zone(store_timezone)

      return false if starts_at.present? && date_in_tz < starts_at
      return false if ends_at.present? && date_in_tz > ends_at

      true
    end
  end
end
