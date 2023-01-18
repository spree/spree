class AllowNullMenuName < ActiveRecord::Migration[6.1]
  def change
    change_column_null :spree_menus, :name, true
  end
end
