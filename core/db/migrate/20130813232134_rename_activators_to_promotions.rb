class RenameActivatorsToPromotions < ActiveRecord::Migration[4.2]
  def change
    rename_table :spree_activators, :spree_promotions
  end
end
