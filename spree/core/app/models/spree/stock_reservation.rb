module Spree
  class StockReservation < Spree.base_class
    has_prefix_id :res

    publishes_lifecycle_events

    belongs_to :stock_item, class_name: 'Spree::StockItem', inverse_of: :stock_reservations
    belongs_to :line_item, class_name: 'Spree::LineItem', inverse_of: :stock_reservations
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :stock_reservations

    validates :stock_item, :line_item, :order, :quantity, :expires_at, presence: true
    validates :quantity, numericality: { greater_than: 0, only_integer: true }
    validates :line_item_id, uniqueness: { scope: :stock_item_id }

    scope :active, -> { where('spree_stock_reservations.expires_at > ?', Time.current) }
    scope :expired, -> { where('spree_stock_reservations.expires_at <= ?', Time.current) }
    scope :for_order, ->(order) { where(order_id: order.id) }
    scope :for_store, ->(store) {
      joins(:order).where(spree_orders: { store_id: store.id })
    }

    self.whitelisted_ransackable_attributes = %w[stock_item_id line_item_id order_id quantity expires_at]
    self.whitelisted_ransackable_associations = %w[stock_item line_item order]

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
  end
end
