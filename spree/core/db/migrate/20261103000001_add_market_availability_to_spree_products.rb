# NULL means "every market", so no existing product needs a row or a backfill.
class AddMarketAvailabilityToSpreeProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_products, :market_availability, :string
    add_index :spree_products, :market_availability, where: 'market_availability IS NOT NULL'

    create_table :spree_product_market_availabilities do |t|
      t.references :product, null: false, index: false
      t.references :market, null: false

      t.timestamps
    end

    add_index :spree_product_market_availabilities, [:product_id, :market_id], unique: true,
              name: 'index_spree_product_market_availabilities_on_product_and_market'
  end
end
