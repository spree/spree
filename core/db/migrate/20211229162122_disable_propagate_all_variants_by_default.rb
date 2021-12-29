class DisablePropagateAllVariantsByDefault < ActiveRecord::Migration[7.0]
  def change
    change_column_default :spree_stock_locations, :propagate_all_variants, false
  end
end
