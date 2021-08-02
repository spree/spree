class CreateSpreeMenus < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_menus do |t|
      t.column :name, :string
      t.column :location, :string
      t.column :locale, :string

      t.belongs_to :store

      t.timestamps
    end

    add_index :spree_menus, :locale
    add_index :spree_menus, [:store_id, :location, :locale], unique: true
  end
end
