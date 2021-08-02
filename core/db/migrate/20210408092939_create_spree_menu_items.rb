class CreateSpreeMenuItems < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_menu_items do |t|
      t.column :name, :string, null: false
      t.column :subtitle, :string
      t.column :destination, :string
      t.column :new_window, :boolean, default: false
      t.column :item_type, :string
      t.column :linked_resource_type, :string, default: 'URL'
      t.column :linked_resource_id, :integer
      t.column :code, :string

      t.column :parent_id, :integer
      t.column :lft, :integer, null: false
      t.column :rgt, :integer, null: false
      t.column :depth, :integer, null: false, default: 0

      t.belongs_to :menu

      t.timestamps
    end

    add_index :spree_menu_items, :lft
    add_index :spree_menu_items, :rgt
    add_index :spree_menu_items, :depth
    add_index :spree_menu_items, :parent_id
    add_index :spree_menu_items, :item_type
    add_index :spree_menu_items, :code
    add_index :spree_menu_items, [:linked_resource_type, :linked_resource_id], name: 'index_spree_menu_items_on_linked_resource'
  end
end
