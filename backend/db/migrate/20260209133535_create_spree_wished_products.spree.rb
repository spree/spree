# This migration comes from spree (originally 20210921070814)
class CreateSpreeWishedProducts < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_wished_products, if_not_exists: true do |t|
      t.references :variant
      t.belongs_to :wishlist

      t.column :quantity, :integer, default: 1, null: false

      t.timestamps
    end

    add_index :spree_wished_products, [:variant_id, :wishlist_id], unique: true unless index_exists?(:spree_wished_products, [:variant_id, :wishlist_id])
    add_index :spree_wished_products, :variant_id unless index_exists?(:spree_wished_products, :variant_id)
    add_index :spree_wished_products, :wishlist_id unless index_exists?(:spree_wished_products, :wishlist_id)
  end
end
