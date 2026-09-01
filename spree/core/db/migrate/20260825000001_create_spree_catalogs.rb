class CreateSpreeCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_catalogs do |t|
      t.references :store, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: false
      t.integer :position
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    # Membership only: a catalog decides what a buyer sees, never the order
    # they see it in, so there is no position here.
    create_table :spree_catalog_products do |t|
      t.references :catalog, null: false
      t.references :product, null: false
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
