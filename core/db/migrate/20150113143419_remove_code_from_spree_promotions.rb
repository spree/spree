class RemoveCodeFromSpreePromotions < ActiveRecord::Migration
  def change
    remove_column :spree_promotions, :code, :string
  end
end
