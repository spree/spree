class CreateSpreePriceHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_price_histories do |t|
      t.references :price, null: false, index: false
      t.references :variant, null: false, index: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :compare_at_amount, precision: 10, scale: 2
      t.string :currency, null: false
      t.datetime :recorded_at, null: false
      t.datetime :created_at, null: false
    end

    add_index :spree_price_histories, [:variant_id, :currency, :recorded_at],
              name: 'idx_price_histories_variant_currency_recorded'
    add_index :spree_price_histories, [:price_id, :recorded_at],
              name: 'idx_price_histories_price_recorded'
    add_index :spree_price_histories, :recorded_at,
              name: 'idx_price_histories_recorded_at'
  end
end
