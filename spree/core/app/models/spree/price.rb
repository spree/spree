module Spree
  class Price < Spree.base_class
    # Which engine produced this answer — nil for Spree's own catalog, a
    # provider's registry key otherwise. Transient: set by
    # Spree::Pricing::PriceResolution on the way out and copied onto the line
    # item as price_source. Not a column, because a catalog row is the same
    # row whoever asked for it.
    attr_accessor :price_source

    # Set by Spree::Prices::BulkDestroy, which has already judged the ladders
    # its whole batch leaves.
    attr_accessor :skip_ladder_check

    has_prefix_id :price

    include Spree::VatPriceCalculation
    include Spree::StorePreferences

    publishes_lifecycle_events

    acts_as_paranoid

    MAXIMUM_AMOUNT = BigDecimal('99_999_999.99')

    # How many breaks one variant may carry on one list in one currency. A UI
    # sanity bound rather than a technical one — but enforced here so no
    # writer can get past it, since the resolver scans a variant's rows for
    # every priced line (docs/plans/6.0-volume-pricing.md).
    MAXIMUM_BREAKS_PER_VARIANT = 10

    belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant', inverse_of: :prices, touch: true
    belongs_to :price_list, class_name: 'Spree::PriceList', optional: true

    has_many :price_histories, class_name: 'Spree::PriceHistory', dependent: :delete_all

    before_validation :ensure_currency
    before_save :remove_compare_at_amount_if_equals_amount
    # Prepended so a refused deletion stops before the callbacks registered
    # above (price histories, the lifecycle event payload) run.
    before_destroy :ensure_ladder_survives_removal, prepend: true
    after_save :record_price_history, if: :should_record_price_history?

    # legacy behavior
    validates :amount, allow_nil: true, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: MAXIMUM_AMOUNT
    }, if: -> { Spree::Config.allow_empty_price_amount }

    # new behavior - prices on a price_list can have nil amounts (placeholder prices)
    validates :amount, allow_nil: false, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: MAXIMUM_AMOUNT
    }, unless: -> { Spree::Config.allow_empty_price_amount || price_list_id.present? }

    validates :compare_at_amount, allow_nil: true, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: MAXIMUM_AMOUNT
    }

    validates :currency, presence: true

    validates :min_quantity, presence: true,
              numericality: { only_integer: true, greater_than: 0 }
    validate :break_requires_price_list
    validate :breaks_within_cap
    validate :ladder_does_not_rise

    scope :with_currency, ->(currency) { where(currency: currency) }
    scope :non_zero, -> { where.not(amount: [nil, 0]) }
    scope :discounted, -> { where('compare_at_amount > amount') }
    scope :base_prices, -> { where(price_list_id: nil) }
    # A variant's rungs above its ordinary price on a list.
    scope :breaks, -> { where.not(min_quantity: 1) }
    scope :for_price_list, ->(price_list) { where(price_list_id: price_list) }
    scope :for_products, lambda { |products, currency = nil|
      currency ||= Spree::Store.default.default_currency

      with_currency(currency).joins(:variant).where(
        Spree::Variant.table_name => { product_id: products }
      )
    }

    extend DisplayMoney
    money_methods :amount, :price, :compare_at_amount
    alias display_compare_at_price display_compare_at_amount

    self.whitelisted_ransackable_attributes = %w[amount compare_at_amount currency min_quantity price_list_id variant_id]
    self.whitelisted_ransackable_associations = %w[variant price_list]
    self.whitelisted_ransackable_scopes = %i[search]

    # Free-text search delegated to `Spree::Variant.search` (SKU + product
    # name + option-value presentation), wrapped in a subquery so that
    # multi-option-value variants don't produce duplicate Price rows —
    # the prices index has `collection_distinct?` off (PG DISTINCT +
    # ORDER BY incompat), so any join-based predicate would double up.
    scope :search, ->(query) {
      next all if query.blank?

      where(variant_id: Spree::Variant.search(query).select(:id))
    }

    attribute :eligible_for_collection_matching, :boolean, default: false
    before_validation -> { self.eligible_for_collection_matching = new_record? ? discounted? : discounted? != was_discounted? }
    after_commit -> { variant&.product&.auto_match_collections }, if: -> { eligible_for_collection_matching? }

    def money
      Spree::Money.new(amount || 0, currency: currency.upcase)
    end

    def amount=(amount)
      self[:amount] = amount.blank? ? nil : Spree::LocalizedNumber.parse(amount)
    end

    # Returns the amount in cents
    # @return [Integer]
    def amount_in_cents
      display_amount&.amount_in_cents
    end

    def compare_at_money
      Spree::Money.new(compare_at_amount || 0, currency: currency)
    end

    def compare_at_amount=(value)
      calculated_value = Spree::LocalizedNumber.parse(value) if value.present?

      self[:compare_at_amount] = calculated_value
    end

    # Returns the compare at amount for display
    # @return [Spree::Money, nil]
    def display_compare_at_amount
      return nil if compare_at_amount.nil?

      Spree::Money.new(compare_at_amount, currency: currency)
    end

    # Returns the compare at amount in cents
    # @return [Integer, nil]
    def compare_at_amount_in_cents
      return nil if compare_at_amount.nil?

      display_compare_at_amount.amount_in_cents
    end

    alias_attribute :price, :amount
    alias_method :price=, :amount=
    alias_attribute :compare_at_price, :compare_at_amount
    alias_method :compare_at_price=, :compare_at_amount=

    # Whether this figure is the merchant's answer for the buyer's geography
    # already. A price list narrowed by market or country states its prices for
    # that geography, so they are charged exactly as entered — restating one would
    # net it out with the *home* rate and destroy the price point the merchant
    # chose. Lists narrowed by anything else (a quantity, a group) were not set
    # for a country, so their prices restate like any other.
    #
    # @return [Boolean]
    def final_for_destination?
      rules = price_list&.price_rules.to_a
      return false unless rules.any?(&:geographic?)

      # Under 'any' the list can win on a non-geographic rule alone, so a
      # geographic rule being present does not mean this buyer's geography is why
      # the price applied. Under 'all' every rule matched, so it does.
      price_list.match_policy == 'all' || rules.all?(&:geographic?)
    end

    def price_including_vat_for(price_options)
      return price if final_for_destination?

      options = price_options.merge(tax_category: variant.tax_category)
      gross_amount(price, options)
    end

    def compare_at_price_including_vat_for(price_options)
      return compare_at_price if final_for_destination?

      options = price_options.merge(tax_category: variant.tax_category)
      gross_amount(compare_at_price, options)
    end

    def display_price_including_vat_for(price_options)
      Spree::Money.new(price_including_vat_for(price_options), currency: currency)
    end

    def display_compare_at_price_including_vat_for(price_options)
      Spree::Money.new(compare_at_price_including_vat_for(price_options), currency: currency)
    end

    # returns the name of the price in a format of variant name and currency
    #
    # @return [String]
    def name
      "#{variant.name} - #{currency.upcase}"
    end

    # returns true if the price is discounted
    #
    # @return [Boolean]
    def discounted?
      compare_at_amount.to_i.positive? && amount.present? && compare_at_amount > amount
    end

    # returns true if the price was discounted
    #
    # @return [Boolean]
    def was_discounted?
      compare_at_amount_was.to_i.positive? && compare_at_amount_was > amount_was
    end

    # returns true if the price is zero
    #
    # @return [Boolean]
    def zero?
      amount.nil? || amount.zero?
    end

    # returns true if the price is not zero
    #
    # @return [Boolean]
    def non_zero?
      !zero?
    end

    # Returns the price history record with the lowest amount in the last 30 days
    # Used for EU Omnibus Directive compliance
    #
    # @return [Spree::PriceHistory, nil]
    def prior_price
      price_histories.where(recorded_at: 30.days.ago..).order(:amount).first
    end

    # Prices carry no store of their own; the variant's product owns it.
    # @return [Spree::Store, nil]
    def preference_store
      variant&.product&.store
    end

    # The first rung of `[[quantity, amount], ...]` costing more than the
    # quantity below it buys — the rung beneath, or `floor` for a ladder
    # starting above one unit. Returned as `[quantity, amount, floor]`.
    #
    # @param ladder [Array<Array>] rungs by quantity
    # @param floor [BigDecimal, nil]
    # @return [Array, nil]
    def self.rising_rung(ladder, floor)
      bottom_quantity, bottom_amount = ladder.first
      return if bottom_quantity.nil?

      # The bottom rung answers to the floor, and is checked first so the rung
      # named is the first breach reading upward — a merchant who fixes what
      # they are told to fix should not meet a second error beneath it.
      if bottom_quantity != 1 && floor.present? && bottom_amount > floor
        return [bottom_quantity, bottom_amount, floor]
      end

      ladder.each_cons(2) do |(_, below), (quantity, amount)|
        return [quantity, amount, below] if amount > below
      end

      nil
    end

    # The ladders that removing these prices would leave charging more for a
    # bigger order. Removing a ladder's bottom rung is how: the next rung then
    # answers to the base price. Judged on what the whole set leaves, so a
    # bottom rung removed together with the breaks above it is allowed. A
    # ladder on a deleted list is skipped, since no buyer pays it.
    #
    # @param prices [Array<Spree::Price>]
    # @return [Array<Hash>] `[{ variant_id:, currency:, price_list_id:, min_quantity:, amount:, floor: }, ...]`
    def self.rising_ladders_without(prices)
      rungs = prices.select { |price| price.price_list_id.present? && !price.amount.nil? }
      return [] if rungs.empty?

      removed_ids = prices.map(&:id)
      variant_ids = rungs.map(&:variant_id).uniq
      currencies = rungs.map(&:currency).uniq
      live_list_ids = Spree::PriceList.where(id: rungs.map(&:price_list_id).uniq).ids.to_set

      remaining = where(variant_id: variant_ids, currency: currencies, price_list_id: live_list_ids.to_a).
                  where.not(amount: nil).where.not(id: removed_ids).
                  pluck(:variant_id, :currency, :price_list_id, :min_quantity, :amount).
                  group_by { |row| row.first(3) }
      floors = base_prices.where(variant_id: variant_ids, currency: currencies).
               where.not(amount: nil).where.not(id: removed_ids).
               pluck(:variant_id, :currency, :amount).
               to_h { |variant_id, currency, amount| [[variant_id, currency], amount] }

      ladders = rungs.map { |price| [price.variant_id, price.currency, price.price_list_id] }.uniq
      ladders.filter_map do |variant_id, currency, list_id|
        next unless live_list_ids.include?(list_id)

        ladder = remaining.fetch([variant_id, currency, list_id], []).map { |row| row.last(2) }.sort_by(&:first)
        breach = rising_rung(ladder, floors[[variant_id, currency]])
        next if breach.nil?

        { variant_id: variant_id, currency: currency, price_list_id: list_id,
          min_quantity: breach[0], amount: breach[1], floor: breach[2] }
      end
    end

    # Whether this row is a quantity break rather than the list's ordinary
    # price for the variant.
    # @return [Boolean]
    def quantity_break?
      min_quantity.to_i > 1
    end

    private

    # Base prices are what a shopper is quoted on a product page, and a
    # quantity-dependent shop price would make every PDP quantity-dependent —
    # a storefront surface v1 deliberately does not open
    # (docs/plans/6.0-volume-pricing.md). Lifting this later is deleting this
    # method; the column is already the right one.
    def break_requires_price_list
      return unless quantity_break?
      return if price_list_id.present?

      errors.add(:min_quantity, :requires_price_list)
    end

    # Counted the way the constant is named: breaks *above* the bottom rung,
    # so a variant priced at one figure plus ten breaks is exactly at the
    # limit. Placeholder rows carry no amount and charge nothing, so they do
    # not fill the ladder — the bulk path counts the same rows, and a cap two
    # writers disagree about is one that refuses what it just allowed.
    def breaks_within_cap
      return unless quantity_break?
      return if price_list_id.blank? || variant_id.blank? || currency.blank?
      return unless will_save_change_to_attribute?(:min_quantity) || new_record?

      siblings = self.class.where(variant_id: variant_id, currency: currency, price_list_id: price_list_id).
                 breaks.where.not(amount: nil)
      siblings = siblings.where.not(id: id) if persisted?
      return if siblings.count < MAXIMUM_BREAKS_PER_VARIANT

      errors.add(:min_quantity, :too_many_breaks, count: MAXIMUM_BREAKS_PER_VARIANT)
    end

    # A break promises a better price for a bigger order, so no rung may cost
    # more than the quantity below it buys. Judged over the ladder this save
    # would leave behind rather than this row alone: lowering one rung strands
    # every rung above it, and a base price is the floor each ladder falls
    # through to. The bulk path judges the same way; this covers the
    # single-row writers, as the break cap is covered on both
    # (docs/plans/6.0-volume-pricing.md).
    def ladder_does_not_rise
      return if amount.nil? || variant_id.blank? || currency.blank?
      return unless new_record? || will_save_change_to_attribute?(:amount) || will_save_change_to_attribute?(:min_quantity)

      breach = affected_ladders.lazy.filter_map { |list_id, floor| self.class.rising_rung(resulting_ladder(list_id), floor) }.first
      return if breach.nil?

      add_rising_ladder_error(:amount, *breach)
    end

    # A deletion is held to the same rule as a save. Skipped when the variant
    # is destroyed along with its prices: a soft delete cascades as
    # `destroyed_by_association`, and paranoia's `really_destroy!` marks each
    # row deleted before running its callbacks.
    def ensure_ladder_survives_removal
      return if skip_ladder_check || destroyed_by_association || deleted?

      breach = self.class.rising_ladders_without([self]).first
      return if breach.nil?

      add_rising_ladder_error(:base, *breach.values_at(:min_quantity, :amount, :floor))
      throw(:abort)
    end

    def add_rising_ladder_error(attribute, quantity, rung_amount, floor)
      errors.add(attribute, :leaves_a_rising_ladder,
                 quantity: quantity,
                 amount: Spree::Money.new(rung_amount, currency: currency),
                 floor: Spree::Money.new(floor, currency: currency))
    end

    # The ladders this row can disturb, each with the floor it falls through
    # to: its own list for a break, and every ladder the variant carries for a
    # base price, since that is the floor they all read.
    #
    # @return [Array<Array>] `[[price_list_id, floor], ...]`
    def affected_ladders
      if price_list_id.present?
        base = self.class.base_prices.where(variant_id: variant_id, currency: currency).
               where.not(amount: nil).pick(:amount)
        return [[price_list_id, base]]
      end

      self.class.where(variant_id: variant_id, currency: currency).
        where.not(price_list_id: nil).where.not(amount: nil).
        distinct.pluck(:price_list_id).map { |list_id| [list_id, amount] }
    end

    # One list's rungs as this save would leave them, by quantity.
    #
    # @return [Array<Array>] `[[quantity, amount], ...]`
    def resulting_ladder(list_id)
      rows = self.class.where(variant_id: variant_id, currency: currency, price_list_id: list_id).where.not(amount: nil)
      rows = rows.where.not(id: id) if persisted?
      rungs = rows.pluck(:min_quantity, :amount).to_h
      rungs[min_quantity] = amount if price_list_id == list_id
      rungs.sort_by(&:first)
    end

    def should_record_price_history?
      price_list_id.nil? &&
        amount.present? &&
        saved_change_to_amount? &&
        store_preference(:track_price_history)
    end

    def record_price_history
      Spree::PriceHistory.create!(
        price: self,
        variant_id: variant_id,
        amount: amount,
        compare_at_amount: compare_at_amount,
        currency: currency,
        recorded_at: Time.current
      )
    end

    def ensure_currency
      self.currency ||= Spree::Store.default.default_currency
    end

    # removes the compare at amount if it is the same as the amount
    def remove_compare_at_amount_if_equals_amount
      self.compare_at_amount = nil if compare_at_amount == amount
    end
  end
end
