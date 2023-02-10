class EnableMenuItemsWithoutName < ActiveRecord::Migration[7.0]
  def change
    change_column_null :spree_menu_items, :name, true
  end
end
