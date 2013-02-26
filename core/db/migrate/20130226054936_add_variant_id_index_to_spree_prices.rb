class AddVariantIdIndexToSpreePrices < ActiveRecord::Migration
  def change
    add_index :spree_prices, :variant_id
  end
end
