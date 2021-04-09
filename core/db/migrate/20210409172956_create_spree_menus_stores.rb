class CreateSpreeMenusStores < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_menus_stores, id: false do |t|
      t.belongs_to :menu
      t.belongs_to :store
    end

    add_index :spree_menus_stores, [:menu_id, :store_id], unique: true, name: 'menu_id_store_id_unique_index'
  end
end
