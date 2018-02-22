class AddUniqueIndexOnSpreePromotionsCode < ActiveRecord::Migration[5.1]
  def change
    remove_index :spree_promotions, :code
    add_index :spree_promotions, :code, unique: true
  end
end
