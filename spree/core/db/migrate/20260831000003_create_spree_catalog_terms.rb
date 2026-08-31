class CreateSpreeCatalogTerms < ActiveRecord::Migration[8.1]
  def change
    # The catalog-wide default, the middle of the three levels a buyer's
    # quantity rules resolve through: variant base -> catalog default ->
    # catalog x variant override. Same column pair at each level.
    add_column :spree_catalogs, :minimum_order_quantity, :integer
    add_column :spree_catalogs, :order_multiple, :integer

    # Strictly the per-variant override — the catalog-wide default lives in
    # the columns above, so there is no null-variant row and the index stays
    # a plain unique one.
    create_table :spree_catalog_quantity_rules do |t|
      t.references :catalog, null: false, index: false
      t.references :variant, null: false
      t.integer :minimum_order_quantity
      t.integer :order_multiple
      t.timestamps
    end

    add_index :spree_catalog_quantity_rules, [:catalog_id, :variant_id], unique: true,
              name: 'idx_catalog_quantity_rules_on_catalog_and_variant'

    # Born per currency: one row per currency, never one amount plus a
    # currency column (the recorded no-FX constraint).
    create_table :spree_catalog_order_minimums do |t|
      t.references :catalog, null: false, index: false
      t.string :currency, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      t.timestamps
    end

    add_index :spree_catalog_order_minimums, [:catalog_id, :currency], unique: true,
              name: 'idx_catalog_order_minimums_on_catalog_and_currency'
  end
end
