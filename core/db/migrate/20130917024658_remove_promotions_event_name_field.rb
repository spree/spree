class RemovePromotionsEventNameField < ActiveRecord::Migration
  def change
    remove_column :spree_promotions, :event_name
  end
end
