class AddTimestampsToOrderPromotions < ActiveRecord::Migration
  def change
    add_column :spree_orders_promotions, :created_at, :datetime
    add_column :spree_orders_promotions, :updated_at, :datetime
  end
end
