module Spree
  class StockReservation < Spree.base_class
    has_prefix_id :res

    publishes_lifecycle_events

    belongs_to :stock_item, class_name: 'Spree::StockItem', inverse_of: :stock_reservations
    belongs_to :line_item, class_name: 'Spree::LineItem', inverse_of: :stock_reservations
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :stock_reservations, optional: true
    belongs_to :cart, class_name: 'Spree::Cart', inverse_of: :stock_reservations, optional: true

    validates :stock_item, :line_item, :quantity, :expires_at, presence: true
    validate :exactly_one_owner
    validates :quantity, numericality: { greater_than: 0, only_integer: true }, presence: true
    validates :line_item_id, uniqueness: { scope: :stock_item_id }, presence: true

    scope :active, -> { where('spree_stock_reservations.expires_at > ?', Time.current) }
    scope :expired, -> { where('spree_stock_reservations.expires_at <= ?', Time.current) }
    scope :for_order, ->(owner) { owner.is_a?(Spree::Cart) ? where(cart_id: owner.id) : where(order_id: owner.id) }
    scope :for_store, ->(store) {
      joins(:order).where(spree_orders: { store_id: store.id })
    }

    self.whitelisted_ransackable_attributes = %w[stock_item_id line_item_id order_id quantity expires_at]
    self.whitelisted_ransackable_associations = %w[stock_item line_item order]

    # @return [Spree::Cart, Spree::Order, nil]
    def owner
      order || cart
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

    # Resolves the reservation TTL: per-Store preference if set, otherwise
    # the global Spree::Config[:default_stock_reservation_ttl_minutes]. Falls
    # back to 10 minutes if both are unset (e.g. early-boot / fixture state).
    def self.ttl_for(order)
      minutes = order&.store&.preferred_stock_reservation_ttl_minutes
      minutes = Spree::Config[:default_stock_reservation_ttl_minutes] if minutes.blank?
      minutes.to_i.then { |m| m > 0 ? m : 10 }.minutes
    end

    private

    def exactly_one_owner
      errors.add(:base, Spree.t('errors.messages.exactly_one_of_cart_or_order')) unless [order, cart].compact.one?
    end
  end
end
