class EnableMenusWithoutName < ActiveRecord::Migration[7.0]
  def change
    change_column_null :spree_menus, :name, true
  end
end
