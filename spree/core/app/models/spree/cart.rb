module Spree
  # The pre-completion (shopping + checkout) phase of a purchase. Completing
  # checkout copies a cart into an immutable {Spree::Order}; the cart is
  # retained with +completed_at+ set. Carts have no status column —
  # +completed_at+ is the only lifecycle marker.
  #
  # Dormant until the 6.0 checkout flip: the storefront cart endpoints still
  # operate on incomplete orders. See docs/plans/6.0-cart-order-split.md.
  class Cart < Spree.base_class
    has_prefix_id :cart

    has_secure_token

    # Concurrency is manual (the API's OrderLock semantics — compare
    # client-sent version, 409 on mismatch); Rails auto-locking must not
    # raise on internal saves.
    self.lock_optimistically = false

    # Single consolidated metadata JSON column (docs/plans/decisions.md
    # 2026-03-16 "Consolidate metadata").
    attribute :metadata, default: -> { {} }
    attribute :accept_marketing, :boolean, default: false

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :market, class_name: 'Spree::Market', optional: true
    belongs_to :channel, class_name: 'Spree::Channel', optional: true
    belongs_to :customer, class_name: "::#{Spree.user_class}", optional: true
    belongs_to :ship_address, class_name: 'Spree::Address', optional: true
    belongs_to :bill_address, class_name: 'Spree::Address', optional: true

    has_many :line_items, -> { order(:created_at) }, class_name: 'Spree::LineItem', inverse_of: :cart, dependent: :destroy
    has_one :order, class_name: 'Spree::Order', inverse_of: :cart

    validates :store, :currency, presence: true

    scope :complete, -> { where.not(completed_at: nil) }
    scope :incomplete, -> { where(completed_at: nil) }

    self.whitelisted_ransackable_attributes = %w[email completed_at]

    # @return [Boolean]
    def completed?
      completed_at.present?
    end

    # @return [Boolean] whether a completion attempt currently holds this cart
    def completing?
      completing_at.present?
    end
  end
end
