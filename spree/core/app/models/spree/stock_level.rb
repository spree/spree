module Spree
  class StockLevel < Spree.base_class
    has_prefix_id :sl

    acts_as_paranoid

    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::HasExternalReferences
    # Dual-emits the pre-rename `stock_item.*` names for one release.
    include Spree::StockLevel::CustomEvents

    publishes_lifecycle_events

    with_options inverse_of: :stock_levels do
      belongs_to :stock_location, class_name: 'Spree::StockLocation'
      belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'
    end
    has_many :stock_movements, inverse_of: :stock_level
    has_many :stock_reservations, class_name: 'Spree::StockReservation', inverse_of: :stock_level, dependent: :destroy
    has_many :active_stock_reservations, -> { active }, class_name: 'Spree::StockReservation', inverse_of: :stock_level

    validates :stock_location, :variant, presence: true
    validates :variant_id, uniqueness: { scope: :stock_location_id }, unless: :deleted_at

    validates :count_on_hand, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2**31 - 1,
      only_integer: true
    }, if: :verify_count_on_hand?

    delegate :weight, :should_track_inventory?, to: :variant
    delegate :name, to: :variant, prefix: true
    delegate :product, to: :variant

    after_save(if: :saved_changes?) { variant.touch }
    after_touch { variant.touch }
    after_destroy { variant.touch }

    self.whitelisted_ransackable_attributes = %w[count_on_hand allocated_count stock_location_id variant_id]
    self.whitelisted_ransackable_associations = %w[variant stock_location]

    scope :with_active_stock_location, -> { joins(:stock_location).merge(Spree::StockLocation.active) }

    # Stock levels for products assigned to `store`, walking
    # `variant → product → store`.
    #
    # Used by the admin API as the base scope so the controller can filter
    # directly by stock_location/variant without inheriting
    # `Spree::Store#stock_levels`'s extra joins or the variant default
    # ordering.
    scope :for_store, ->(store) {
      joins(variant: :product).where(spree_products: { store_id: store.id })
    }

    def backordered_inventory_units
      Spree::InventoryUnit.backordered_for_stock_level(self)
    end

    # @api private
    # Physical stock changes through movements only — call a
    # {Spree::StockLocation} verb rather than this, so the change leaves an
    # audit row. Keeps the locked read-modify-write that
    # {#process_backorders} needs the delta for.
    #
    # @param force [Boolean] let the write leave the shelf below zero. Only a
    #   forced dispatch asks for this: the merchant has decided the parcel
    #   left whatever the ledger claims.
    def adjust_count_on_hand(value, force: false)
      with_lock do
        set_count_on_hand(count_on_hand + value, force: force)
      end
    end

    # @param force [Boolean] see {#adjust_count_on_hand}
    def set_count_on_hand(value, force: false)
      @forced_count_on_hand = force
      self.count_on_hand = value
      process_backorders(count_on_hand - count_on_hand_was)

      save!
    ensure
      # Scoped to this write: the exemption must not outlive the call that
      # asked for it.
      @forced_count_on_hand = false
    end

    # Units that are physically here and not already promised to a placed
    # order — what a customer can still buy from this level.
    def in_stock?
      available_count.positive?
    end

    # Tells whether it's available to be included in a shipment
    def available?
      in_stock? || backorderable?
    end

    # Promised units go up and down atomically: two fulfillments allocating
    # the same level concurrently must not read each other's value first, and
    # neither counter update needs the delta that count_on_hand's locked path
    # exists for.
    #
    # Touched afterwards because the counter write is a bare SQL update: it
    # runs no callbacks, so without this a placement taking the last unit would
    # leave the variant's cache keys and the search index claiming it is still
    # for sale, and would publish no stock_level.updated. Under the old model
    # the same change went through `save`, and this is what restores it.
    #
    # @param value [Integer] signed change
    # @return [void]
    def adjust_allocated_count(value)
      value.negative? ? decrement!(:allocated_count, value.abs) : increment!(:allocated_count, value)
      touch
    end

    # Withdraws up to +units+ of promise. Only a promise that exists can be
    # withdrawn — stock that leaves without ever having been allocated (a
    # stock transfer, or a fulfillment created before typed movements) must
    # not drive the counter below zero, which would make the level look more
    # available than it is.
    #
    # Locked, unlike its counterpart {#adjust_allocated_count}: the cap is read
    # from the same counter the write then moves, so two concurrent releases
    # reading before either writes would both pass a cap that only covered one
    # of them.
    #
    # @param units [Integer]
    # @return [void]
    def release_allocated_count(units)
      with_lock do
        withdrawn = [units.abs, allocated_count].min
        next if withdrawn.zero?

        adjust_allocated_count(-withdrawn)
      end
    end

    # Physical stock minus allocated units at this stock level. Distinct from
    # {Spree::Stock::Quantifier#available_stock}, which sums this across all
    # stock levels belonging to a variant.
    #
    # @return [Integer]
    def available_count
      count_on_hand - allocated_count
    end

    def reduce_count_on_hand_to_zero
      set_count_on_hand(0) if count_on_hand > 0
    end

    private

    # A shelf can only be driven below zero by a write that asked to, and then
    # it means Spree never saw those goods arrive — a receiving gap that heals
    # itself when the missing `received` movement lands. Every other writer, a
    # correction above all, is stopped: a hand-typed count below zero is a
    # typo, not a fact.
    def verify_count_on_hand?
      count_on_hand_changed? && count_on_hand.negative? &&
        count_on_hand < count_on_hand_was && !@forced_count_on_hand
    end

    # Process backorders based on amount of stock received
    # If stock was -20 and is now -15 (increase of 5 units), then we can process atmost 5 inventory orders.
    # If stock was -20 but then was -25 (decrease of 5 units), do nothing.
    def process_backorders(number)
      return unless number.positive?

      units = backordered_inventory_units.first(number) # We can process atmost n backorders
      filled_units = []

      units.each do |unit|
        break unless number.positive?

        # What this unit takes of the arriving stock — the whole unit, or the
        # part of it the arrival covers. Read before the split, because the
        # split leaves `unit.quantity` holding the *remainder*, and subtracting
        # that would let the next unit be filled from stock already spoken for.
        filled = [unit.quantity, number].min

        if unit.quantity > number
          # if required quantity is greater than available
          # split off and fulfill that
          split = unit.split_inventory!(number)
          filled_units << split if split.fill_backorder!
        else
          filled_units << unit if unit.fill_backorder!
        end
        number -= filled
      end

      # One recalculation per affected order, after the whole arrival is
      # allocated — filling five backorders on one order is one order update,
      # not five.
      filled_units.filter_map(&:order).uniq.each(&:fulfill!)
    end
  end
end
