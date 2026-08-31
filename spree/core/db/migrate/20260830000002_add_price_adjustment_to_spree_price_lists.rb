class AddPriceAdjustmentToSpreePriceLists < ActiveRecord::Migration[8.1]
  def change
    # Signed: negative is a discount off the base price, positive a markup.
    # nil means the list prices only what it holds explicit rows for, which
    # is every list that exists today
    # (docs/plans/6.0-price-list-automatic-pricing.md).
    add_column :spree_price_lists, :price_adjustment_percentage, :decimal, precision: 6, scale: 3

    # Whether a derived price also derives its compare-at from the base
    # compare-at. Off by default: a derived compare-at is a claim about a
    # former price, so it is stated deliberately.
    add_column :spree_price_lists, :adjust_compare_at, :boolean, null: false, default: false
  end
end
