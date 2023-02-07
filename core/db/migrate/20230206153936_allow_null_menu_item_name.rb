class AllowNullMenuItemName < ActiveRecord::Migration[6.1]
  def change
    change_column_null :spree_menu_items, :name, true
  end
end
