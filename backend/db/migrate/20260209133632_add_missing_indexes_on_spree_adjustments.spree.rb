# This migration comes from spree (originally 20250914101955)
class AddMissingIndexesOnSpreeAdjustments < ActiveRecord::Migration[7.2]
  def change
    add_index :spree_adjustments, :source_type, if_not_exists: true
    add_index :spree_adjustments, :amount, if_not_exists: true
  end
end
