class AddMinQuantityToSpreePrices < ActiveRecord::Migration[8.1]
  def change
    # The quantity a line must reach for this row to be its price. Defaulting
    # to 1 makes every existing row a quantity-1 price, so a ladder is purely
    # additive and there is nothing to backfill
    # (docs/plans/6.0-volume-pricing.md).
    add_column :spree_prices, :min_quantity, :integer, null: false, default: 1

    # Row identity gains the column: a variant now holds one price per
    # (currency, list, break) rather than one per (currency, list).
    remove_index :spree_prices, name: 'index_spree_prices_on_variant_currency_price_list', if_exists: true

    if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
      add_index :spree_prices, [:variant_id, :currency, :price_list_id, :min_quantity],
                name: 'index_spree_prices_on_variant_currency_list_quantity',
                unique: true
    else
      add_index :spree_prices, [:variant_id, :currency, :price_list_id, :min_quantity],
                name: 'index_spree_prices_on_variant_currency_list_quantity',
                unique: true,
                where: 'price_list_id IS NOT NULL AND deleted_at IS NULL AND amount IS NOT NULL'
    end

    # Reading a ladder means "this variant's rows on this list, ordered by
    # break" — the unique index above leads with variant_id, so it serves
    # that read too, and no second index is warranted.
  end
end
