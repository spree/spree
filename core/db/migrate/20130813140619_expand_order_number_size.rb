class ExpandOrderNumberSize < ActiveRecord::Migration[4.2]
  def up
    change_column :spree_orders, :number, :string, limit: 32
  end

  def down
    change_column :spree_orders, :number, :string, limit: 15
  end
end
