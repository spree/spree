class CreateSpreeMenuItems < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_menu_items do |t|
      t.column :name, :string
      t.column :subtitle, :string
      t.column :url, :string
      t.column :new_window, :boolean, default: false
      t.column :item_type, :string
      t.column :linked_resource_type, :string
      t.column :linked_resource_id, :integer
      t.column :position, :integer, default: 0
      t.column :parent_id, :integer, default: 0
      t.belongs_to :menu

      t.timestamps
    end
  end
end
