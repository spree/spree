class FixPromotionCodeAndPathUniqueIndexes < ActiveRecord::Migration[5.2]
  def change
    # removing unique indexes
    remove_index :spree_promotions, :code
    # applying standard indexes
    add_index :spree_promotions, :code
    add_index :spree_promotions, :path unless index_exists?(:spree_promotions, :path)
  end
end
