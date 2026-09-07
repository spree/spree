module Spree
  # One SKU on a stock transfer: how many left the source warehouse, and how
  # many the destination counted in.
  class StockTransferItem < Spree.base_class
    has_prefix_id :sti

    include Spree::ReceivableItem

    expects_quantity_in :quantity_shipped

    belongs_to :stock_transfer, class_name: 'Spree::StockTransfer', inverse_of: :items, touch: true

    validates :quantity_shipped, numericality: { greater_than: 0, only_integer: true }
    validates :variant_id, uniqueness: { scope: :stock_transfer_id }

    self.whitelisted_ransackable_attributes = %w[variant_id quantity_shipped quantity_received discrepancy_reason]
    self.whitelisted_ransackable_associations = %w[variant]
  end
end
