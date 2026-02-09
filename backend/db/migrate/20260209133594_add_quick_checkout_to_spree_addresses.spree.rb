# This migration comes from spree (originally 20250110171203)
class AddQuickCheckoutToSpreeAddresses < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_addresses, :quick_checkout, :boolean, default: false, if_not_exists: true
    add_index :spree_addresses, :quick_checkout, if_not_exists: true
  end
end
