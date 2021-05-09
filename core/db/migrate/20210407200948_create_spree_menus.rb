class CreateSpreeMenus < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_menus do |t|
      t.column :name, :string
      t.column :location, :string
      t.column :locale, :string

      t.belongs_to :store

      t.timestamps
    end

    add_index :spree_menus, :name
    add_index :spree_menus, :location
    add_index :spree_menus, :locale
  end
end
