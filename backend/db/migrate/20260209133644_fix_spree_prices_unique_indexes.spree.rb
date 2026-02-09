# This migration comes from spree (originally 20260112000000)
class FixSpreePricesUniqueIndexes < ActiveRecord::Migration[7.0]
  def change
    remove_index :spree_prices, name: 'index_spree_prices_on_variant_currency_price_list', if_exists: true

    if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
      # MySQL doesn't support partial indexes, so we use a composite unique index
      # that includes price_list_id. NULL values are treated as distinct in MySQL unique indexes,
      # so this allows multiple base prices (price_list_id = NULL) per variant/currency
      # but only one price per variant/currency/price_list combination.
      # Keep existing index_spree_prices_on_variant_id_and_currency as-is (non-unique, for performance).
      add_index :spree_prices, [:variant_id, :currency, :price_list_id],
                name: 'index_spree_prices_on_variant_currency_price_list',
                unique: true
    else
      # PostgreSQL and SQLite support partial indexes
      remove_index :spree_prices, name: 'index_spree_prices_on_variant_id_and_currency', if_exists: true

      # Add unique index for base prices only (price_list_id IS NULL)
      # The amount IS NOT NULL condition allows placeholder prices with nil amounts
      add_index :spree_prices, [:variant_id, :currency],
                name: 'index_spree_prices_on_variant_id_and_currency',
                unique: true,
                where: 'price_list_id IS NULL AND deleted_at IS NULL AND amount IS NOT NULL'

      # Add unique index for price list prices (one price per variant/currency/price_list)
      # The amount IS NOT NULL condition allows placeholder prices with nil amounts
      add_index :spree_prices, [:variant_id, :currency, :price_list_id],
                name: 'index_spree_prices_on_variant_currency_price_list',
                unique: true,
                where: 'price_list_id IS NOT NULL AND deleted_at IS NULL AND amount IS NOT NULL'
    end
  end
end
