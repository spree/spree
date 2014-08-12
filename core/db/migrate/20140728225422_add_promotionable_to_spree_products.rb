class AddPromotionableToSpreeProducts < ActiveRecord::Migration
  def change
    add_column :spree_products, :promotionable, :boolean, default: true
  end
end
