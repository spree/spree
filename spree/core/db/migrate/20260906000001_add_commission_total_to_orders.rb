class AddCommissionTotalToOrders < ActiveRecord::Migration[8.1]
  # What this sale earned the marketplace, denormalized from the order's
  # commission lines the way fee_total is denormalized from its fees.
  #
  # Deliberately not part of the grand total: a commission is a platform to
  # seller settlement the customer never pays, so these are readable sums
  # beside the money the shopper owes, never an addition to it.
  #
  # Split three ways because the tax is the point. The marketplace's
  # commission is its own taxable B2B supply to the seller, so the platform
  # files that VAT as output tax and the seller reclaims the same figure as
  # input tax. A single gross column cannot answer either question — the tax
  # is not recoverable from it — and a VAT return is not filed from a sum
  # recomputed in a browser. Mirrors how the order already carries
  # included_tax_total and additional_tax_total beside the totals they belong
  # to.
  def change
    add_column :spree_orders, :commission_amount_total, :decimal, precision: 10, scale: 2, null: false, default: 0.0
    add_column :spree_orders, :commission_tax_total, :decimal, precision: 10, scale: 2, null: false, default: 0.0
    add_column :spree_orders, :commission_total, :decimal, precision: 10, scale: 2, null: false, default: 0.0
  end
end
