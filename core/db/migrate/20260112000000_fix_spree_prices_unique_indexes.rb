class FixSpreePricesUniqueIndexes < ActiveRecord::Migration[7.0]
  def change
    # Remove old unique index that doesn't account for price_list_id
    # This index prevents creating price list prices when a base price exists
    remove_index :spree_prices, name: 'index_spree_prices_on_variant_id_and_currency', if_exists: true

    # Remove the composite index that was added with price_list_id
    remove_index :spree_prices, name: 'index_spree_prices_on_variant_currency_price_list', if_exists: true

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
