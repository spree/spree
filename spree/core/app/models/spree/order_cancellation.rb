module Spree
  class OrderCancellation < Spree.base_class
    has_prefix_id :cncl

    REASONS = %w[customer declined fraud inventory staff other expired].freeze

    attribute :restock_items, :boolean, default: false
    attribute :refund_payments, :boolean, default: false
    attribute :notify_customer, :boolean, default: false
    attribute :metadata, default: -> { {} }

    belongs_to :order, class_name: 'Spree::Order', inverse_of: :cancellations
    belongs_to :canceled_by, polymorphic: true, optional: true

    validates :order, presence: true
    validates :reason, presence: true, inclusion: { in: REASONS }
    validates :refund_amount, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  end
end
