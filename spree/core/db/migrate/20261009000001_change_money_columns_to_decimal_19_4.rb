# Widens every money column to decimal(19,4): room for a dinar's third decimal,
# sub-cent unit prices and very large amounts. Every stored value fits exactly,
# so no value changes. A column already at (19,4) is skipped, so an install
# that widened its largest tables online ahead of the upgrade runs this as a
# no-op for those (see the 5.6 to 6.0 upgrade guide).
class ChangeMoneyColumnsToDecimal194 < ActiveRecord::Migration[8.1]
  COLUMNS = {
    spree_adjustments: %i[amount],
    spree_carts: %i[additional_tax_total adjustment_total delivery_total discount_total fee_total included_tax_total
                    item_total non_taxable_adjustment_total payment_total taxable_adjustment_total total],
    spree_catalog_order_minimums: %i[amount],
    spree_claim_line_items: %i[additional_tax_total included_tax_total refund_amount],
    spree_commission_lines: %i[amount tax_amount total],
    spree_commission_rate_values: %i[amount max_amount min_amount],
    spree_delivery_method_services: %i[markup_flat],
    spree_delivery_methods: %i[markup_flat],
    spree_delivery_rates: %i[cost],
    spree_discounts: %i[amount value],
    spree_exchange_line_items: %i[new_additional_tax_total new_included_tax_total original_additional_tax_total
                                  original_included_tax_total],
    spree_fees: %i[amount],
    spree_fulfillments: %i[additional_tax_total adjustment_total cost discount_total included_tax_total
                           non_taxable_adjustment_total pre_tax_amount taxable_adjustment_total],
    spree_gift_card_batches: %i[amount],
    spree_gift_cards: %i[amount amount_authorized amount_used],
    spree_line_items: %i[additional_tax_total adjustment_total cost_price discount_total included_tax_total
                         non_taxable_adjustment_total pre_tax_amount price taxable_adjustment_total],
    spree_orders: %i[additional_tax_total adjustment_total commission_amount_total commission_tax_total commission_total
                     delivery_total discount_total fee_total included_tax_total item_total non_taxable_adjustment_total
                     payment_total taxable_adjustment_total total],
    spree_payment_capture_events: %i[amount],
    spree_payment_sessions: %i[amount],
    spree_payment_splits: %i[authorized_amount captured_amount claimed_amount refunded_amount],
    spree_payments: %i[amount],
    spree_price_histories: %i[amount compare_at_amount],
    spree_prices: %i[amount compare_at_amount],
    spree_products: %i[revenue],
    spree_products_stores: %i[revenue],
    spree_purchase_order_items: %i[unit_cost],
    spree_refunds: %i[amount tax_amount],
    spree_reimbursement_credits: %i[amount],
    spree_reimbursements: %i[total],
    spree_return_items: %i[additional_tax_total included_tax_total pre_tax_amount],
    spree_return_line_items: %i[additional_tax_total included_tax_total pre_tax_amount],
    spree_seller_payouts: %i[amount],
    spree_seller_transfers: %i[amount settled_amount],
    spree_sellers: %i[minimum_payout_amount],
    spree_shipping_labels: %i[cost],
    spree_stock_movements: %i[unit_cost],
    spree_store_credit_events: %i[amount user_total_amount],
    spree_store_credits: %i[amount amount_authorized amount_used],
    spree_tax_lines: %i[amount],
    spree_variants: %i[cost_price]
  }.freeze

  # What `down` restores: decimal(10,2) unless listed.
  ORIGINAL = {
    'spree_delivery_rates.cost' => [8, 2],
    'spree_store_credit_events.amount' => [8, 2],
    'spree_store_credit_events.user_total_amount' => [8, 2],
    'spree_store_credits.amount' => [8, 2],
    'spree_store_credits.amount_authorized' => [8, 2],
    'spree_store_credits.amount_used' => [8, 2],
    'spree_fulfillments.pre_tax_amount' => [12, 4],
    'spree_line_items.pre_tax_amount' => [12, 4],
    'spree_return_items.additional_tax_total' => [12, 4],
    'spree_return_items.included_tax_total' => [12, 4],
    'spree_return_items.pre_tax_amount' => [12, 4],
    'spree_products.revenue' => [16, 4]
  }.freeze

  def up
    each_column { |table, column| widen(table, column, 19, 4) }
  end

  def down
    each_column do |table, column|
      precision, scale = ORIGINAL.fetch("#{table}.#{column}", [10, 2])
      widen(table, column, precision, scale)
    end
  end

  private

  def each_column
    COLUMNS.each do |table, columns|
      next unless table_exists?(table)

      columns.each { |column| yield(table, column) if column_exists?(table, column) }
    end
  end

  def widen(table, name, precision, scale)
    column = connection.columns(table).find { |candidate| candidate.name == name.to_s }
    return if column.precision == precision && column.scale == scale

    change_column table, name, :decimal, precision: precision, scale: scale, null: column.null, default: column.default
  end
end
