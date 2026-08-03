module Spree
  # A customer sends items back and gets their money back.
  #
  # Replaces the ReturnAuthorization → CustomerReturn → Reimbursement chain
  # with one record that owns the whole operation
  # (docs/plans/6.0-returns-exchanges-claims.md). The legacy chain still
  # exists and is untouched; this is the surface new code should use.
  #
  # The model holds associations, validations and pure reads only. Every
  # transition is a workflow — `Spree::Returns::Receive.call(...)`, never
  # `return.receive!` — so receiving can take the quantities the warehouse
  # actually counted, and refunding can call a payment gateway outside the
  # transaction that writes the status.
  class Return < Spree.base_class
    has_prefix_id :ret

    include Spree::Core::NumberGenerator.new(prefix: 'RET', length: 9)
    include Spree::NumberIdentifier
    include Spree::SingleStoreResource
    include Spree::HasStatus
    include Spree::Metadata

    publishes_lifecycle_events

    has_status :requested, :approved, :received, :refunded, :canceled,
               default: :requested

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :returns
    belongs_to :stock_location, class_name: 'Spree::StockLocation'
    belongs_to :reason, class_name: 'Spree::ReturnAuthorizationReason', optional: true
    # Staff only. Customer-initiated returns leave this nil — the requester
    # is always order.customer, so no second association is needed.
    belongs_to :created_by, class_name: Spree.admin_user_class.to_s, optional: true

    has_many :return_line_items, class_name: 'Spree::ReturnLineItem',
                                 dependent: :destroy, inverse_of: :return
    has_many :refunds, class_name: 'Spree::Refund', as: :originator, dependent: :nullify

    validates :order, :stock_location, presence: true
    validates :return_line_items, presence: true, on: :create

    accepts_nested_attributes_for :return_line_items, allow_destroy: true

    delegate :currency, to: :order

    self.whitelisted_ransackable_attributes = %w[number status created_at]
    self.whitelisted_ransackable_associations = %w[order reason]

    # What the customer is owed for the items being returned.
    def refund_total
      return_line_items.sum(&:pre_tax_amount)
    end

    # What has actually been refunded so far — a return can be refunded in
    # more than one step (part to store credit, part to the card).
    def refunded_total
      refunds.sum(:amount)
    end

    def refundable_total
      refund_total - refunded_total
    end

    def display_refund_total
      Spree::Money.new(refund_total, currency: currency)
    end
  end
end
