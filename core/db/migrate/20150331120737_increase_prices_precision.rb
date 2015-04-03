class IncreasePricesPrecision < ActiveRecord::Migration
  def change
    change_column :spree_adjustments, :amount,                :decimal, precision: 12, scale: 6

    change_column :spree_line_items, :price,                 :decimal, precision: 12, scale: 6,               null: false
    change_column :spree_line_items, :cost_price,            :decimal, precision: 12, scale: 6
    change_column :spree_line_items, :adjustment_total,      :decimal, precision: 12, scale: 6, default: 0.0
    change_column :spree_line_items, :additional_tax_total,  :decimal, precision: 12, scale: 6, default: 0.0
    change_column :spree_line_items, :promo_total,           :decimal, precision: 12, scale: 6, default: 0.0
    change_column :spree_line_items, :included_tax_total,    :decimal, precision: 12, scale: 6, default: 0.0, null: false
    change_column :spree_line_items, :pre_tax_amount,        :decimal, precision: 12, scale: 6, default: 0.0

    change_column :spree_orders, :item_total,                 :decimal, precision: 12, scale: 6, default: 0.0,     null: false
    change_column :spree_orders, :total,                      :decimal, precision: 12, scale: 6, default: 0.0,     null: false
    change_column :spree_orders, :adjustment_total,           :decimal, precision: 12, scale: 6, default: 0.0,     null: false
    change_column :spree_orders, :payment_total,              :decimal, precision: 12, scale: 6, default: 0.0
    change_column :spree_orders, :shipment_total,             :decimal, precision: 12, scale: 6, default: 0.0,     null: false
    change_column :spree_orders, :additional_tax_total,       :decimal, precision: 12, scale: 6, default: 0.0
    change_column :spree_orders, :promo_total,                :decimal, precision: 12, scale: 6, default: 0.0
    change_column :spree_orders, :included_tax_total,         :decimal, precision: 12, scale: 6, default: 0.0,     null: false

    change_column :spree_prices,      :amount,                :decimal, precision: 12, scale: 6

    change_column :spree_payment_capture_events, :amount,     :decimal, precision: 12, scale: 6, default: 0.0

    change_column :spree_payments, :amount,                   :decimal, precision: 12, scale: 6, default: 0.0, null: false

    change_column :spree_refunds, :amount,                    :decimal, precision: 12, scale: 6, default: 0.0, null: false

    change_column :spree_reimbursement_credits, :amount,      :decimal, precision: 12, scale: 6, default: 0.0, null: false

    change_column :spree_reimbursements, :total,              :decimal, precision: 12, scale: 6

    change_column :spree_return_items, :additional_tax_total, :decimal, precision: 12, scale: 6, default: 0.0
    change_column :spree_return_items, :included_tax_total,   :decimal, precision: 12, scale: 6, default: 0.0, null: false
    change_column :spree_return_items, :pre_tax_amount,       :decimal, precision: 12, scale: 6, default: 0.0

    change_column :spree_shipments, :cost,                    :decimal, precision: 12, scale: 6, default: 0.0
    change_column :spree_shipments, :adjustment_total,        :decimal, precision: 12, scale: 6, default: 0.0
    change_column :spree_shipments, :additional_tax_total,    :decimal, precision: 12, scale: 6, default: 0.0
    change_column :spree_shipments, :promo_total,             :decimal, precision: 12, scale: 6, default: 0.0
    change_column :spree_shipments, :included_tax_total,      :decimal, precision: 12, scale: 6, default: 0.0, null: false
    change_column :spree_shipments, :pre_tax_amount,          :decimal, precision: 12, scale: 6, default: 0.0

    change_column :spree_shipping_rates, :cost,               :decimal, precision: 12, scale: 6, default: 0.0

    change_column :spree_tax_rates, :amount,                  :decimal, precision: 8, scale: 6, default: 0.0

    change_column :spree_variants, :cost_price,               :decimal, precision: 12, scale: 6
  end
end
