module Spree
  # One delivery against a purchase order or a stock transfer: what the dock
  # counted in on one day, under one packing slip. Lines on the document keep
  # the running totals; the receipt is the record of each arrival, and every
  # `received` movement it caused names it.
  #
  # A *stock* receipt on purpose — a customer-facing sales receipt will want
  # the plain word.
  class StockReceipt < Spree.base_class
    has_prefix_id :sr

    include Spree::SingleStoreResource
    has_spree_number prefix: 'SR'
    include Spree::NumberIdentifier
    include Spree::Metadata

    publishes_lifecycle_events

    belongs_to :receivable, polymorphic: true, inverse_of: :stock_receipts
    belongs_to :received_by, class_name: Spree.admin_user_class.to_s, optional: true

    has_many :items, class_name: 'Spree::StockReceiptItem', inverse_of: :stock_receipt,
                     dependent: :destroy
    has_many :stock_movements, class_name: 'Spree::StockMovement', inverse_of: :stock_receipt,
                               dependent: :nullify

    validates :received_at, presence: true
    validates :items, presence: true

    normalizes :reference, with: ->(value) { value.strip.presence }

    self.whitelisted_ransackable_attributes = %w[number reference received_at receivable_type
                                                 receivable_id received_by_id created_at]

    # @return [Integer] units this delivery put on the shelf
    def quantity_accepted_total
      items.sum { |item| item.quantity_accepted.to_i }
    end

    # @return [Integer] units this delivery refused
    def quantity_rejected_total
      items.sum { |item| item.quantity_rejected.to_i }
    end

    def event_serializer_class
      'Spree::Api::V3::StockReceiptEventSerializer'.safe_constantize
    end

    private

    def ensure_store
      self.store ||= receivable&.store
      super
    end
  end
end
