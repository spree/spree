class RenameActivatorsToPromotions < ActiveRecord::Migration
  def change
    rename_table :spree_activators, :spree_promotions
  end
end
