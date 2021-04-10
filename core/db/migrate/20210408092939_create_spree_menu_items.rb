class CreateSpreeMenuItems < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_menu_items do |t|
      t.column :name, :string
      t.column :subtitle, :string
      t.column :url, :string
      t.column :new_window, :boolean, default: false
      t.column :item_type, :string
      t.column :container, :boolean, default: false
      t.column :linked_resource_type, :string, default: 'URL'
      t.column :linked_resource_id, :integer
      t.column :parent_id, :integer
      t.column :lft, :integer
      t.column :rgt, :integer

      t.belongs_to :menu

      t.timestamps
    end

    add_index :spree_menu_items, [:parent_id]
    add_index :spree_menu_items, [:lft]
    add_index :spree_menu_items, [:rgt]
  end
end
