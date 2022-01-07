class AddNoteToSpreeOrders < ActiveRecord::Migration[5.2]
  def change
    add_column :spree_orders, :note, :text
  end
end
