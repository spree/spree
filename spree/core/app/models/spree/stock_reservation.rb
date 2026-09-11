module Spree
  class StockReservation < Spree.base_class
    has_prefix_id :res

    publishes_lifecycle_events

    belongs_to :stock_level, class_name: 'Spree::StockLevel', inverse_of: :stock_reservations
    belongs_to :line_item, class_name: 'Spree::LineItem', inverse_of: :stock_reservations
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :stock_reservations, optional: true
    belongs_to :cart, class_name: 'Spree::Cart', inverse_of: :stock_reservations, optional: true

    alias_attribute :stock_item_id, :stock_level_id

    after_create :hold_units
    after_update :move_held_units, if: :saved_change_to_quantity?
    after_destroy :release_units

    validates :quantity, :expires_at, presence: true
    validate :exactly_one_owner
    validates :quantity, numericality: { greater_than: 0, only_integer: true }, presence: true
    validates :line_item_id, uniqueness: { scope: :stock_level_id }, presence: true

    scope :active, -> { where('spree_stock_reservations.expires_at > ?', Time.current) }
    scope :expired, -> { where('spree_stock_reservations.expires_at <= ?', Time.current) }
    scope :for_order, ->(owner) { owner.is_a?(Spree::Cart) ? where(cart_id: owner.id) : where(order_id: owner.id) }
    scope :for_store, ->(store) {
      joins(:order).where(spree_orders: { store_id: store.id })
    }

    # `stock_item_id` rides along for one release beside the name that replaced
    # it — see the same allowlist on Spree::StockMovement.
    self.whitelisted_ransackable_attributes = %w[stock_level_id stock_item_id line_item_id order_id
                                                 quantity expires_at]
    self.whitelisted_ransackable_associations = %w[stock_level line_item order]

    # Deletes these reservations in one statement and hands their units back
    # to each level's reserved counter in the same transaction — the batch
    # twin of the per-row callbacks, for a sweep or a release that would
    # otherwise destroy rows one by one.
    #
    # The levels are locked first, then the rows read and deleted: the order
    # {Spree::StockReservations::Reserve} takes, so a checkout re-reserving
    # one of these rows waits at the level rather than the two of them
    # locking each other out, and its new quantity cannot land between the
    # read and the delete.
    #
    # @param reservations [ActiveRecord::Relation<Spree::StockReservation>]
    # @return [Integer] how many reservations were deleted
    def self.withdraw(reservations)
      transaction do
        levels = Spree::StockLevel.where(id: reservations.select(:stock_level_id)).order(:id).lock.to_a
        held = reservations.group(:stock_level_id).sum(:quantity)
        deleted = reservations.delete_all

        levels.each { |stock_level| stock_level.adjust_reserved_count(-held.fetch(stock_level.id, 0)) }

        deleted
      end
    end

    # Removes every hold whose time is up, giving the units back to their
    # levels. Run by {Spree::StockReservations::ExpireJob} on a schedule and
    # by the stock recount before it measures anything.
    #
    # @return [void]
    def self.sweep_expired
      expired.in_batches(of: 1_000) { |batch| withdraw(batch) }
    end

    # @return [Spree::Cart, Spree::Order, nil]
    def owner
      order || cart
    end

    # @deprecated Use {#stock_level}; removed in 6.1.
    def stock_item
      Spree::Deprecation.warn('Spree::StockReservation#stock_item is deprecated and will be removed in Spree 6.1. Use #stock_level instead.')
      stock_level
    end

    # @deprecated Use {#stock_level=}; removed in 6.1.
    def stock_item=(record)
      Spree::Deprecation.warn('Spree::StockReservation#stock_item= is deprecated and will be removed in Spree 6.1. Use #stock_level= instead.')
      self.stock_level = record
    end

    # Bridge for legacy callers assigning +current_order+ (now a Spree::Cart)
    # to the order association — routes carts to the cart FK instead.
    def order=(record)
      if record.is_a?(Spree::Cart)
        self.cart = record
        super(nil)
      else
        super
      end
    end

    def active?
      expires_at > Time.current
    end

    # Resolves the reservation TTL from the store, falling back to 10 minutes
    # when there is no store to ask (early-boot / fixture state).
    def self.ttl_for(order)
      minutes = order&.store&.preferred_stock_reservation_ttl_minutes
      minutes.to_i.then { |m| m > 0 ? m : 10 }.minutes
    end

    private

    # The counter follows the row wherever the row goes: a checkout that
    # reserves, a cart that is emptied, a line item that is removed, a level
    # that is destroyed — every path that creates, resizes or destroys a
    # reservation moves the level's figure by exactly that row.
    def hold_units
      stock_level.adjust_reserved_count(quantity)
    end

    def move_held_units
      before, after = saved_change_to_quantity
      stock_level.adjust_reserved_count(after - before.to_i)
    end

    def release_units
      stock_level&.adjust_reserved_count(-quantity)
    end

    def exactly_one_owner
      errors.add(:base, :exactly_one_of_cart_or_order, message: Spree.t('errors.messages.exactly_one_of_cart_or_order')) unless [order, cart].compact.one?
    end
  end
end
