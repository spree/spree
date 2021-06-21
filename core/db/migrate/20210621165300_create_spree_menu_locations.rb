class CreateSpreeMenuLocations < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_menu_locations do |t|
      t.string :name, null: false
      t.string :parameterized_name, null: false

      t.timestamps
    end

    add_index :spree_menu_locations, :name
    add_index :spree_menu_locations, :parameterized_name
  end
end
