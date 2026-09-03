module Spree
  # A customer sends items back and gets their money back.
  #
  # One record owns the whole operation — permission, physical receipt and
  # money back (docs/plans/6.0-returns-exchanges-claims.md), replacing the
  # ReturnAuthorization → CustomerReturn → Reimbursement chain removed in 6.0.
  #
  # The model holds associations, validations and pure reads only. Every
  # transition is a workflow — `Spree::Returns::Receive.call(...)`, never
  # `return.receive!` — so receiving can take the quantities the warehouse
  # actually counted, and refunding can call a payment gateway outside the
  # transaction that writes the status.
  class Return < Spree.base_class
    has_prefix_id :ret

    has_spree_number prefix: 'RET'
    include Spree::NumberIdentifier
    include Spree::SingleStoreResource
    include Spree::HasStatus
    include Spree::HasCustomFields
    include Spree::Metadata

    publishes_lifecycle_events

    has_status :requested, :approved, :received, :refunded, :canceled,
               default: :requested

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :returns
    belongs_to :stock_location, class_name: 'Spree::StockLocation'
    belongs_to :reason, class_name: 'Spree::ReturnReason', optional: true, inverse_of: :returns
    # Staff only. Customer-initiated returns leave this nil — the requester
    # is always order.customer, so no second association is needed.
    belongs_to :created_by, class_name: Spree.admin_user_class.to_s, optional: true

    has_many :return_line_items, class_name: 'Spree::ReturnLineItem',
                                 dependent: :destroy, inverse_of: :return
    has_many :refunds, class_name: 'Spree::Refund', as: :originator, dependent: :nullify
    has_many :store_credits, class_name: 'Spree::StoreCredit', as: :originator, dependent: :nullify
    # The return label and the inbound parcel's journey
    # (docs/plans/6.0-shipping-labels-and-deliveries.md). A delivery reporting
    # arrival never receives the return: arrival is not inspection.
    has_many :shipping_labels, -> { order(:created_at, :id) }, class_name: 'Spree::ShippingLabel', as: :owner, dependent: :destroy
    has_many :deliveries, -> { order(:created_at, :id) }, class_name: 'Spree::Delivery', as: :owner, dependent: :destroy

    validates :return_line_items, presence: true, on: :create

    accepts_nested_attributes_for :return_line_items, allow_destroy: true

    delegate :currency, to: :order

    self.whitelisted_ransackable_attributes = %w[number status created_at]
    self.whitelisted_ransackable_associations = %w[order reason]

    # The label that currently binds the inbound parcel — bought or uploaded,
    # not refunded. The label workflows refuse a second active one.
    #
    # @return [Spree::ShippingLabel, nil]
    def active_shipping_label
      shipping_labels.active.last
    end

    # The provider that ships this return's label — the one that handled the
    # outbound parcel the returned items travelled in, since that is the
    # carrier account the merchant connected. Manual when nothing shipped
    # through a provider.
    #
    # @return [Spree::FulfillmentProvider::Base]
    def provider
      return_line_items.first&.fulfillment_item&.fulfillment&.provider || Spree::FulfillmentProvider::Manual.new
    end

    # The address the inbound parcel leaves from: where the order shipped to.
    #
    # @return [Spree::Address, nil]
    def ship_from_address
      order.ship_address
    end

    # The returned goods as a package, for providers that need a weight and
    # dimensions to rate a return label. Built at the return's stock
    # location, which is where the parcel is going.
    #
    # @return [Spree::Stock::Package]
    def to_package
      package = Spree::Stock::Package.new(stock_location)
      package.owner = order
      units = return_line_items.includes(:fulfillment_item).filter_map(&:fulfillment_item)
      units.group_by(&:status).each { |status, items| package.add_multiple(items, status.to_sym) }
      package
    end

    # What the customer is owed for the items being returned.
    def refund_total
      return_line_items.sum(&:pre_tax_amount)
    end

    # What has actually been refunded so far — a return can be refunded in
    # more than one step (part to store credit, part to the card), and store
    # credit is its own ledger rather than a Spree::Refund row.
    def refunded_total
      refunds.sum(:amount) + store_credits.sum(:amount)
    end

    def refundable_total
      refund_total - refunded_total
    end

    def display_refund_total
      Spree::Money.new(refund_total, currency: currency)
    end

    def display_refunded_total
      Spree::Money.new(refunded_total, currency: currency)
    end
  end
end
