# This migration comes from spree (originally 20211229162122)
class DisablePropagateAllVariantsByDefault < ActiveRecord::Migration[5.2]
  def change
    change_column_default :spree_stock_locations, :propagate_all_variants, false
  end
end
