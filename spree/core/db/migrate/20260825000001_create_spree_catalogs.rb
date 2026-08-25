class CreateSpreeCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_catalogs do |t|
      t.references :store, null: false
      t.references :price_list             # nil = assortment-only, base prices
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :position
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    create_table :spree_catalog_products do |t|
      t.references :catalog, null: false
      t.references :product, null: false
      t.integer :position
      t.timestamps
    end

    add_index :spree_catalog_products, [:catalog_id, :product_id], unique: true,
              name: 'idx_catalog_products_on_catalog_and_product'

    # Who sees a catalog: Channel, CustomerGroup, Market, or Company (where it
    # applies to the node's subtree).
    create_table :spree_catalog_assignments do |t|
      t.references :catalog, null: false
      t.references :assignable, polymorphic: true, null: false
      t.timestamps
    end

    add_index :spree_catalog_assignments, [:catalog_id, :assignable_type, :assignable_id],
              unique: true, name: 'idx_catalog_assignments_uniqueness'

    add_reference :spree_channels, :default_catalog
  end
end
