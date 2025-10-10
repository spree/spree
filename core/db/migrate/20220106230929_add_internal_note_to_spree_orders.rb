class AddInternalNoteToSpreeOrders < ActiveRecord::Migration[5.2]
  def change
    add_column :spree_orders, :internal_note, :text
  end
end
