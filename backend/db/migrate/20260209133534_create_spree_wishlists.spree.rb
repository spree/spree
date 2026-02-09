# This migration comes from spree (originally 20210921070813)
class CreateSpreeWishlists < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_wishlists, if_not_exists: true do |t|
      t.belongs_to :user
      t.belongs_to :store

      t.column :name, :string
      t.column :token, :string, null: false
      t.column :is_private, :boolean, default: true, null: false
      t.column :is_default, :boolean, default: false, null: false

      t.timestamps
    end

    add_index :spree_wishlists, :token, unique: true
    add_index :spree_wishlists, [:user_id, :is_default] unless index_exists?(:spree_wishlists, [:user_id, :is_default])
  end
end
