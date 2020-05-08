class AddCompareAtAmountToSpreePrices < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:spree_prices, :compare_at_amount)
      add_column :spree_prices, :compare_at_amount, :decimal, precision: 10, scale: 2
    end
  end
end
