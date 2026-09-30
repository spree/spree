class AddReplacementToSpreeFulfillmentItems < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_fulfillment_items, :replacement, :boolean, default: false, null: false
  end
end
