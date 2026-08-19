module Spree
  class StockReservation < Spree.base_class
    has_prefix_id :res

    publishes_lifecycle_events

    belongs_to :stock_level, class_name: 'Spree::StockLevel', inverse_of: :stock_reservations
    belongs_to :line_item, class_name: 'Spree::LineItem', inverse_of: :stock_reservations
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :stock_reservations, optional: true
    belongs_to :cart, class_name: 'Spree::Cart', inverse_of: :stock_reservations, optional: true

    alias_attribute :stock_item_id, :stock_level_id

    validates :stock_level, :line_item, :quantity, :expires_at, presence: true
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

    def exactly_one_owner
      errors.add(:base, Spree.t('errors.messages.exactly_one_of_cart_or_order')) unless [order, cart].compact.one?
    end
  end
end
