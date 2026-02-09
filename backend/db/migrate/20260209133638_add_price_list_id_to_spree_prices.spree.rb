# This migration comes from spree (originally 20251110120002)
class AddPriceListIdToSpreePrices < ActiveRecord::Migration[7.0]
  def change
    add_reference :spree_prices, :price_list, null: true
    add_index :spree_prices, [:variant_id, :currency, :price_list_id], name: 'index_spree_prices_on_variant_currency_price_list', unique: true
  end
end
