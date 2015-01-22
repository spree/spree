class AddCodeToSpreePromotionCategories < ActiveRecord::Migration
  def change
    add_column :spree_promotion_categories, :code, :string
  end
end
