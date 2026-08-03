module Spree
  # A customer sends items back and gets different ones — a different size,
  # colour or product.
  #
  # First-class rather than the legacy "a ReturnItem that happens to carry an
  # exchange_variant_id, processed through ReimbursementType::Exchange": you
  # can now ask for all exchanges this month, or every exchange awaiting
  # fulfillment, without digging through return items.
  #
  # Transitions are workflows (docs/plans/6.0-returns-exchanges-claims.md).
  class Exchange < Spree.base_class
    has_prefix_id :exch

    include Spree::Core::NumberGenerator.new(prefix: 'EX', length: 9)
    include Spree::NumberIdentifier
    include Spree::SingleStoreResource
    include Spree::HasStatus
    include Spree::Metadata

    publishes_lifecycle_events

    has_status :requested, :approved, :received, :fulfilled, :canceled,
               default: :requested

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :exchanges
    belongs_to :stock_location, class_name: 'Spree::StockLocation'
    belongs_to :reason, class_name: 'Spree::ReturnAuthorizationReason', optional: true
    belongs_to :created_by, class_name: Spree.admin_user_class.to_s, optional: true

    has_many :exchange_line_items, class_name: 'Spree::ExchangeLineItem',
                                   dependent: :destroy, inverse_of: :exchange
    has_many :refunds, class_name: 'Spree::Refund', as: :originator, dependent: :nullify

    validates :order, :stock_location, presence: true
    validates :exchange_line_items, presence: true, on: :create

    accepts_nested_attributes_for :exchange_line_items, allow_destroy: true

    delegate :currency, to: :order

    self.whitelisted_ransackable_attributes = %w[number status created_at]
    self.whitelisted_ransackable_associations = %w[order reason]

    # Positive when the replacements cost more than what came back (the
    # customer owes the difference), negative when they cost less (a refund
    # is due).
    def price_difference
      exchange_line_items.sum(&:price_difference)
    end

    def display_price_difference
      Spree::Money.new(price_difference, currency: currency)
    end
  end
end
