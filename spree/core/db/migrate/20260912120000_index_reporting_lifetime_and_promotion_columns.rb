class IndexReportingLifetimeAndPromotionColumns < ActiveRecord::Migration[8.1]
  # Customer lifetime value correlates a customer's whole order history on
  # email, which `spree_orders` had no index for at all — so every customer
  # group in a report drove a full scan of the orders table, and the metric
  # became unusable well before a store got large. Store first, because every
  # reporting query is store-scoped before it is anything else.
  #
  # The promotion breakdown probes discounts per line item, filtered to
  # promotion rows; carrying `kind` in the index keeps those probes from
  # visiting the row itself.
  def change
    add_index :spree_orders, %i[store_id email]
    add_index :spree_discounts, %i[line_item_id kind]
  end
end
