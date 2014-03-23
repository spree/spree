class AddDeletedAtToSpreePrices < ActiveRecord::Migration
  def change
    add_column :spree_prices, :deleted_at, :datetime
  end
end
