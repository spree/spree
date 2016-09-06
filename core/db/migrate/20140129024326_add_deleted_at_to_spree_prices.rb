class AddDeletedAtToSpreePrices < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_prices, :deleted_at, :datetime
  end
end
