class CreateSpreeMenus < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_menus do |t|
      t.column :name, :string

      t.timestamps
    end

    add_index :spree_menus, :name
  end
end
