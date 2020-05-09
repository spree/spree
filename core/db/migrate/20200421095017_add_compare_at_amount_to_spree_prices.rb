class AddCompareAtAmountToSpreePrices < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_prices, :compare_at_amount, :decimal, precision: 10, scale: 2
  end
end
