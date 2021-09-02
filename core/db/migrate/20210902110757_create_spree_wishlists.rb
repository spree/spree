class CreateSpreeWishlists < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_wishlists, if_not_exists: true do |t|
      t.references :user

      t.column :name, :string
      t.column :token, :string
      t.column :is_private, :boolean, default: true, null: false
      t.column :is_default, :boolean, default: false, null: false

      t.timestamps
    end

    add_index :spree_wishlists, [:user_id, :is_default] unless index_exists?(:spree_wishlists, [:user_id, :is_default])
  end
end
