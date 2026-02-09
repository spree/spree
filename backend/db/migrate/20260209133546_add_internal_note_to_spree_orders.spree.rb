# This migration comes from spree (originally 20220106230929)
class AddInternalNoteToSpreeOrders < ActiveRecord::Migration[5.2]
  def change
    add_column :spree_orders, :internal_note, :text
  end
end
