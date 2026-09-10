module Spree
  # Goods bought from a supplier and expected at one of the merchant's own
  # warehouses (docs/plans/6.0-inventory-operations.md).
  #
  # Replaces the 5.x "external receive" — a {Spree::StockTransfer} with no
  # source location — with a record that has the things a purchase actually
  # has: a supplier, a unit cost, an expected date and a number to quote back.
  #
  # Ordered units never count toward availability. Nothing here touches
  # `count_on_hand` until {Spree::PurchaseOrders::Receive} runs, because the
  # merchant only has the goods once they land.
  #
  # Every status change is a workflow — `Spree::PurchaseOrders::Receive`, never
  # `purchase_order.receive!` — so receiving can take the quantities the
  # warehouse counted rather than assuming the order arrived intact.
  class PurchaseOrder < Spree.base_class
    has_prefix_id :po

    # Before `has_spree_number` — see the note on Spree::StockTransfer.
    include Spree::SingleStoreResource
    has_spree_number prefix: 'PO'
    include Spree::NumberIdentifier
    include Spree::HasStatus
    include Spree::Receivable
    include Spree::HasCustomFields
    include Spree::Metadata

    publishes_lifecycle_events

    has_status :draft, :ordered, :partially_received, :received, :over_received, :canceled,
               default: :draft

    belongs_to :supplier, class_name: 'Spree::Supplier', inverse_of: :purchase_orders,
                          counter_cache: true
    belongs_to :destination_location, class_name: 'Spree::StockLocation'
    belongs_to :created_by, class_name: Spree.admin_user_class.to_s, optional: true

    has_many :items, class_name: 'Spree::PurchaseOrderItem',
                     inverse_of: :purchase_order, dependent: :destroy
    # No `dependent:` — the ledger outlives the record that caused it, the same
    # reason Spree::Fulfillment gives for its own movements.
    has_many :stock_movements, class_name: 'Spree::StockMovement', inverse_of: :purchase_order

    accepts_nested_attributes_for :items, allow_destroy: true

    before_validation :ensure_currency

    validates :currency, presence: true
    validates :items, presence: true, unless: -> { draft? || canceled? }

    # Overdue and past-cancel-by read the calendar date in the server's zone;
    # a supplier's promise is a day, and a few hours either side of midnight
    # is not what a merchant is filtering for.
    scope :overdue, -> { open.where(arel_table[:expected_at].lt(Date.current)) }
    scope :past_cancel_by, -> { open.where(arel_table[:cancel_by].lt(Date.current)) }

    self.whitelisted_ransackable_attributes = %w[number status currency reference expected_at
                                                 cancel_by ordered_at received_at closed_short_at
                                                 supplier_id destination_location_id created_at]
    self.whitelisted_ransackable_scopes = %w[open closed overdue past_cancel_by]
    self.whitelisted_ransackable_associations = %w[supplier destination_location items]

    # What the supplier will invoice for everything ordered.
    #
    # @return [BigDecimal]
    def subtotal
      items.sum(&:total_cost)
    end

    # @return [Spree::Money]
    def display_subtotal
      Spree::Money.new(subtotal, currency: currency)
    end

    # Whether the merchant may still edit the lines. Once the order is placed
    # with the supplier, what was ordered is a matter of record.
    #
    # @return [Boolean]
    def editable?
      draft?
    end

    def event_serializer_class
      'Spree::Api::V3::PurchaseOrderEventSerializer'.safe_constantize
    end

    private

    # A foreign-currency purchase order is legitimate, so this is a default
    # rather than a derived value: pass `currency` to override it.
    def ensure_currency
      self.currency ||= store&.default_currency
    end
  end
end
